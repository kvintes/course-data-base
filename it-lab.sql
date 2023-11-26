--      1задание      --
-- 1. Написать команды создания таблиц заданной схемы с указанием
-- необходимых ключей и ограничений. Должны быть установлены все
-- ограничения первичного и внешних ключей. Все ограничения должны
-- быть именованными (для первичных ключей имена должны
-- начинаться с префикса «PK_», для вторичного ключа – «FK_»,
-- проверки - «CH_»). Все имена полей и типы данных должны
-- полностью соответствовать схеме (до языка и регистра).

-- Ограничения: дата начала восхождения не может быть больше даты
-- завершения восхождения; значение высоты не может отрицательным;
-- значение null допустимо только в поле адрес.
-- Для каждой таблицы должна быть возможна вставка картежа без
-- указания первичного ключа.

-- создать таблицы с ограничениями всех видов ключей
-- все ограничения должны быть именнованными
-- язык, тип данных, регистр и имена полей должны совпадать
-- соблюсти ограничения
-- для каждой таблицы есть возможность вставки ключа без указания первичного ключа

--SET search_path TO it, public; -- проишем путь к схеме
-- 1шаг создаем таблицу Альпинист-Восхождение +
create table if not EXISTS it.Альпинист_Восхождение
(
    ID_Альпиниста integer not null
    , ID_Восхождения integer not null
    , constraint PK_Альпинист_Восхождение primary key (ID_Альпиниста, ID_Восхождения)
)
;
-- 2шаг Альпинист-Восхождение возможность вставки кортежа без указания первичного ключа +
CREATE SEQUENCE IF NOT EXISTS it.Альпинист_Восхождение_Альп_seq MINVALUE 0;
alter TABLE Альпинист_Восхождение alter column ID_Альпиниста set DEFAULT nextval('Альпинист_Восхождение_Альп_seq');
ALTER SEQUENCE Альпинист_Восхождение_Альп_seq OWNED BY Альпинист_Восхождение.id_Альпиниста;

CREATE SEQUENCE IF NOT EXISTS it.Альпинист_Восхождение_Восх_seq MINVALUE 1000;
alter TABLE Альпинист_Восхождение alter column ID_Восхождения set DEFAULT nextval('Альпинист_Восхождение_Восх_seq');
ALTER SEQUENCE Альпинист_Восхождение_Восх_seq OWNED BY Альпинист_Восхождение.id_Восхождения;

-- 3шаг создаем таблицу Альпинисты +
--drop table Альпинисты;
create table if not EXISTS it.Альпинисты
(
    ID_Альпиниста integer not null
    , ФИО text not null
    , Адрес text -- значение null допустимо только в поле адрес
    , Телефон text not null
    , Дата_рождения date not null
    , constraint PK_Альпинисты primary key (ID_Альпиниста)
)
;

-- 4шаг Альпинисты возможность вставки кортежа без указания первичного ключа +
CREATE SEQUENCE IF NOT EXISTS it.Альпинисты_seq MINVALUE 0;
alter TABLE Альпинисты alter column ID_Альпиниста set DEFAULT nextval('Альпинисты_seq');
ALTER SEQUENCE Альпинисты_seq OWNED BY Альпинисты.id_Альпиниста;

--5 шаг внешний ключ +
--  Альпинист_Восхождение -> Альпинисты
ALTER TABLE Альпинист_Восхождение ADD
constraint FK_Альпинист_Восние__Альпинисты
FOREIGN KEY (ID_Альпиниста)
REFERENCES Альпинисты (ID_Альпиниста)
ON DELETE CASCADE

-- 6шаг создаем таблицу Восхождения +
--drop table Восхождения;
create table if not EXISTS it.Восхождения
(
    ID_Восхождения integer not null
    , Дата_начала timestamp not null
    , Дата_завершения timestamp not null
    , ID_Вершины integer not null
    , constraint PK_Восхождения primary key (ID_Восхождения)
)
;

-- 7шаг Восхождения возможность вставки кортежа без указания первичного ключа +
CREATE SEQUENCE IF NOT EXISTS it.Восхождения_seq MINVALUE 0;
alter TABLE Восхождения alter column ID_Восхождения set DEFAULT nextval('Восхождения_seq');
ALTER SEQUENCE Восхождения_seq OWNED BY Восхождения.ID_Восхождения;

--8 шаг внешний ключ +
--  Альпинист_Восхождение -> Восхождения
ALTER TABLE Альпинист_Восхождение ADD
constraint FK_Альпинист_Восние__Восхождения
FOREIGN KEY (ID_Восхождения)
REFERENCES Восхождения (ID_Восхождения)
ON DELETE CASCADE

--9 шаг добавление ограничений на Дата_начала < Дата_завершения +
ALTER TABLE Восхождения DROP CONSTRAINT IF EXISTS CH_dates_begin_end;
ALTER TABLE Восхождения ADD CONSTRAINT CH_dates_begin_end CHECK (Дата_начала < Дата_завершения)
;

-- 10шаг создаем таблицу Вершины +
--drop table if exists Вершины;
create table if not EXISTS it.Вершины
(
    ID_Вершины integer not null
    , Название text not null
    , Высота integer not null -- значение высоты не может отрицательным
    , Страна text not null
    , Регион text not null
    , constraint PK_Вершины primary key (ID_Вершины)
)
;

--11 шаг добавление ограничений на Дата_начала < Дата_завершения +
ALTER TABLE Вершины DROP CONSTRAINT IF EXISTS CH_heights;
ALTER TABLE Вершины ADD CONSTRAINT CH_heights CHECK (Высота >= 0)
;

--12 шаг внешний ключ +
--  Восхождения -> Вершины
ALTER TABLE Восхождения ADD
constraint FK_Восхождения__Вершины
FOREIGN KEY (ID_Вершины)
REFERENCES Вершины (ID_Вершины)
ON DELETE CASCADE

-- 13шаг Восхождения возможность вставки кортежа без указания первичного ключа +
CREATE SEQUENCE IF NOT EXISTS it.Вершины_seq MINVALUE 0;
alter TABLE Вершины alter column ID_Вершины set DEFAULT nextval('Вершины_seq');
ALTER SEQUENCE Вершины_seq OWNED BY Вершины.ID_Вершины;

------------------------------------------------------------------------------------------
--      2задание      --
--Заполнить созданные таблицы данными, 
--5-10 записей для каждой таблицы.

--1 шаг добавляем данные в таблицу Альпинисты
INSERT INTO Альпинисты (ФИО, Адрес, Телефон, Дата_рождения) 
