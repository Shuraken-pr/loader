-- =====================================================================
-- Каталог деталей: схема БД
-- СУБД: PostgreSQL 12+
-- Кодировка: UTF-8
-- =====================================================================

BEGIN;

-- ---------------------------------------------------------------------
-- 1. Категории (иерархическое дерево)
-- ---------------------------------------------------------------------
CREATE TABLE categories (
    id          SERIAL       PRIMARY KEY,
    parent_id   INT          REFERENCES categories(id)
                                ON DELETE RESTRICT
                                ON UPDATE CASCADE
                                DEFERRABLE INITIALLY DEFERRED,
    name        VARCHAR(255) NOT NULL,
    created_at  TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at  TIMESTAMPTZ  NOT NULL DEFAULT now(),

    CONSTRAINT uq_categories_parent_name UNIQUE (parent_id, name)
);
-- Для корневых категорий parent_id IS NULL — уникальность по (NULL, name)
-- в PostgreSQL работает корректно (NULL != NULL, поэтому несколько корней
-- с одинаковым именем допустимы — это нормальное поведение).

CREATE INDEX idx_categories_parent ON categories(parent_id);

COMMENT ON TABLE  categories IS 'Иерархия категорий каталога деталей';
COMMENT ON COLUMN categories.parent_id IS 'Родительская категория; NULL = корень';

-- ---------------------------------------------------------------------
-- 2. Определения атрибутов (настраиваются для каждой категории)
-- ---------------------------------------------------------------------
CREATE TYPE attr_type AS ENUM ('string', 'number', 'date', 'boolean');

CREATE TABLE attribute_defs (
    id           SERIAL       PRIMARY KEY,
    category_id  INT          NOT NULL REFERENCES categories(id)
                                 ON DELETE RESTRICT
                                 ON UPDATE CASCADE,
    name         VARCHAR(255) NOT NULL,
    attr_type    attr_type    NOT NULL,
    is_required  BOOLEAN      NOT NULL DEFAULT TRUE,  -- по ТЗ все обязательны
    created_at   TIMESTAMPTZ  NOT NULL DEFAULT now(),

    CONSTRAINT uq_attribute_category_name UNIQUE (category_id, name)
);

CREATE INDEX idx_attribute_defs_category ON attribute_defs(category_id);

COMMENT ON TABLE attribute_defs IS 'Шаблоны атрибутов, настроенные для каждой категории';

-- ---------------------------------------------------------------------
-- 3. Детали
-- ---------------------------------------------------------------------
CREATE TABLE parts (
    id           SERIAL        PRIMARY KEY,
    code         VARCHAR(100)  NOT NULL,
    category_id  INT           NOT NULL REFERENCES categories(id)
                                  ON DELETE RESTRICT
                                  ON UPDATE CASCADE,
    created_at   TIMESTAMPTZ   NOT NULL DEFAULT now(),
    updated_at   TIMESTAMPTZ   NOT NULL DEFAULT now(),

    CONSTRAINT uq_parts_code UNIQUE (code)
);

CREATE INDEX idx_parts_category ON parts(category_id);
CREATE INDEX idx_parts_code     ON parts(code);

COMMENT ON TABLE parts IS 'Детали каталога; code — глобально уникальный код';

-- ---------------------------------------------------------------------
-- 4. Значения атрибутов деталей (EAV: одна строка = одно значение)
-- ---------------------------------------------------------------------
CREATE TABLE part_values (
    part_id       INT          NOT NULL REFERENCES parts(id)
                                  ON DELETE CASCADE
                                  ON UPDATE CASCADE,
    attribute_id  INT          NOT NULL REFERENCES attribute_defs(id)
                                  ON DELETE RESTRICT
                                  ON UPDATE CASCADE,
    value_string  VARCHAR(2000),
    value_number  NUMERIC(18, 6),
    value_date    DATE,
    value_bool    BOOLEAN,

    CONSTRAINT pk_part_values PRIMARY KEY (part_id, attribute_id),

    -- Ровно одно из четырёх полей должно быть заполнено
    CONSTRAINT chk_single_value CHECK (
        (CASE WHEN value_string IS NOT NULL THEN 1 ELSE 0 END) +
        (CASE WHEN value_number IS NOT NULL THEN 1 ELSE 0 END) +
        (CASE WHEN value_date   IS NOT NULL THEN 1 ELSE 0 END) +
        (CASE WHEN value_bool   IS NOT NULL THEN 1 ELSE 0 END) = 1
    )
);

CREATE INDEX idx_part_values_attribute ON part_values(attribute_id);

COMMENT ON TABLE part_values IS 'Значения атрибутов деталей (EAV)';

-- ---------------------------------------------------------------------
-- 5. Триггер: автообновление updated_at
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION trgfn_set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at := now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_categories_updated
    BEFORE UPDATE ON categories
    FOR EACH ROW EXECUTE FUNCTION trgfn_set_updated_at();

CREATE TRIGGER trg_parts_updated
    BEFORE UPDATE ON parts
    FOR EACH ROW EXECUTE FUNCTION trgfn_set_updated_at();

-- ---------------------------------------------------------------------
-- 6. Триггер: проверка обязательности атрибутов при INSERT/UPDATE детали
--    Для каждой детали должны быть заполнены ВСЕ атрибуты её категории.
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION trgfn_check_required_attributes()
RETURNS TRIGGER AS $$
DECLARE
    v_missing_count INT;
BEGIN
    SELECT COUNT(*) INTO v_missing_count
    FROM attribute_defs a
    WHERE a.category_id = NEW.category_id
      AND a.is_required
      AND NOT EXISTS (
          SELECT 1 FROM part_values pv
          WHERE pv.part_id = NEW.id
            AND pv.attribute_id = a.id
            AND (
                   pv.value_string IS NOT NULL
                OR pv.value_number IS NOT NULL
                OR pv.value_date   IS NOT NULL
                OR pv.value_bool   IS NOT NULL
            )
      );

    IF v_missing_count > 0 THEN
        RAISE EXCEPTION 'Не заполнены обязательные атрибуты (кол-во: %)', v_missing_count
            USING ERRCODE = '23514';
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Триггер срабатывает после INSERT/UPDATE детали (чтобы part_values уже были)
CREATE CONSTRAINT TRIGGER trg_parts_check_attrs
    AFTER INSERT OR UPDATE ON parts
    DEFERRABLE INITIALLY DEFERRED
    FOR EACH ROW EXECUTE FUNCTION trgfn_check_required_attributes();

-- ---------------------------------------------------------------------
-- 7. Триггер: проверка соответствия типа атрибута и заполненной колонки
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION trgfn_check_value_type()
RETURNS TRIGGER AS $$
DECLARE
    v_type attr_type;
BEGIN
    SELECT a.attr_type INTO v_type
    FROM attribute_defs a WHERE a.id = NEW.attribute_id;

    IF v_type IS NULL THEN
        RAISE EXCEPTION 'Атрибут id=% не найден', NEW.attribute_id;
    END IF;

    CASE v_type
        WHEN 'string'  THEN IF NEW.value_string IS NULL THEN
            RAISE EXCEPTION 'Для строкового атрибута value_string обязателен'; END IF;
        WHEN 'number'  THEN IF NEW.value_number IS NULL THEN
            RAISE EXCEPTION 'Для числового атрибута value_number обязателен'; END IF;
        WHEN 'date'    THEN IF NEW.value_date   IS NULL THEN
            RAISE EXCEPTION 'Для атрибута-даты value_date обязателен'; END IF;
        WHEN 'boolean' THEN IF NEW.value_bool   IS NULL THEN
            RAISE EXCEPTION 'Для логического атрибута value_bool обязателен'; END IF;
    END CASE;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_part_values_check_type
    BEFORE INSERT OR UPDATE ON part_values
    FOR EACH ROW EXECUTE FUNCTION trgfn_check_value_type();

-- ---------------------------------------------------------------------
-- 8. Вспомогательное представление: «плоский» каталог для отчётов
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW v_parts_full AS
SELECT
    p.id           AS part_id,
    p.code,
    p.category_id,
    c.name         AS category_name,
    a.id           AS attribute_id,
    a.name         AS attribute_name,
    a.attr_type,
    pv.value_string,
    pv.value_number,
    pv.value_date,
    pv.value_bool
FROM parts p
    JOIN categories c     ON c.id = p.category_id
    JOIN attribute_defs a ON a.category_id = c.id
    LEFT JOIN part_values pv ON pv.part_id = p.id AND pv.attribute_id = a.id;

CREATE TABLE user_sessions (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL,
    session_token VARCHAR(64) UNIQUE NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP NOT NULL
);

-- Индекс для быстрого поиска токена
CREATE INDEX idx_user_sessions_token ON user_sessions(session_token);


COMMIT;