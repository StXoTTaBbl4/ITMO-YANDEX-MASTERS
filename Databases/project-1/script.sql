-- create table raw_data.sales (
--     id                  integer,
--     auto                text,
--     gasoline_consumption numeric,
--     price               numeric,
--     date                date,
--     person_name         text,
--     phone               text,
--     discount            integer,
--     brand_origin        text
-- );

-- COPY raw_data.sales (
--     id,
--     auto,
--     gasoline_consumption,
--     price,
--     date,
--     person_name,
--     phone,
--     discount,
--     brand_origin
-- )
-- from 'D:\ITMO\ITMO-YANDEX-MASTERS\Databases\project-1\cars.csv'
-- with (
--     format csv,
--     header true,
--     delimeter ',',
--     null 'null'
-- );

-- create schema car_shop;

-- drop table if exists car_shop.sales;
-- drop table if exists car_shop.country;
-- drop table if exists car_shop.brand;
-- drop table if exists car_shop.model;
-- drop table if exists car_shop.color;
-- drop table if exists car_shop.customer;

-- create table car_shop.country (
-- 	country_id serial primary key, -- serial для автоинкремента
-- 	name varchar(60) -- Нет страны, название которой превышает 60 символов
-- );

-- create table car_shop.brand (
-- 	brand_id serial primary key, -- serial для автоинкремента
-- 	brand_name text unique not null, -- Не может быть пустым и должно быть уникальным
-- 	brand_origin_id integer references car_shop.country
-- );

-- create table car_shop.model (
-- 	model_id serial primary key, -- serial для автоинкремента
-- 	model_name text not null, -- Не может быть пустым
-- 	brand_id integer references car_shop.brand, -- для связи с брендом машины
-- 	unique (brand_id, model_name) -- Связка модель-бренд должна быть уникальной
-- );

-- create table car_shop.color (
-- 	color_id serial primary key, -- serial для автоинкремента
-- 	color_name text  unique not null -- Не может быть пустым и должно быть уникальным
-- );

-- create table car_shop.customer (
-- 	customer_id serial primary key, -- serial для автоинкремента
-- 	person_name text not null, -- Может повторяться (владеет несколькими авто), не может быть пустым.
-- 	phone varchar(30) not null -- Может повторяться, не может быть пустым. Содержит цифры и символы. Максимальная длина в данных - 22, так что 30 для запаса.
-- );

-- create table car_shop.sales (
-- 	id serial primary key, -- serial для автоинкремента
-- 	customer_id integer not null references car_shop.customer,
-- 	model_id integer not null references car_shop.model, -- для связи с моделью машины
-- 	color_id integer not null references car_shop.color, -- для связи с цветом машины
--  	gasoline_consumption numeric(3, 1) check (gasoline_consumption > 0), -- Потребление, может быть null, может быть дробным числом больше 0. Целая часть не превышает двузначного числа. Дробная часть включает только десятые доли
-- 	price numeric(12, 2) not null check (price > 0), -- Цена с дробной частью. Не может быть null, должна быть больше 0
-- 	date date not null, -- Дата, без указания времени 
-- 	discount smallint default 0 check (discount between 0 and 100) -- По умолчанию скидки нет, число помещается в наименьший числовой тип. Может быть от 0 до 100
-- );

-- insert into car_shop.country (name) 
-- select distinct brand_origin 
-- from raw_data.sales
-- where brand_origin is not null;

-- insert into car_shop.brand (brand_name, brand_origin_id)
-- select distinct split_part(auto, ' ', 1), car_shop.country.country_id 
-- from raw_data.sales
-- left join car_shop.country 
-- on raw_data.sales.brand_origin = car_shop.country.name;

-- insert into car_shop.model (model_name, brand_id)
-- select distinct (substring(split_part(auto, ',', 1) from ' (.+)')), cbrand.brand_id
-- from raw_data.sales
-- left join car_shop.brand as cbrand
-- on cbrand.brand_name = split_part(auto, ' ', 1);

-- insert into car_shop.color (color_name)
-- select distinct split_part(auto, ',', 2) from raw_data.sales;

-- insert into car_shop.customer (person_name, phone)
-- select distinct person_name, phone from raw_data.sales;












