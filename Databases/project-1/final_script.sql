create schema raw_data;

create table raw_data.sales (
    id                  integer,
    auto                text,
    gasoline_consumption numeric,
    price               numeric,
    date                date,
    person_name         text,
    phone               text,
    discount            integer,
    brand_origin        text
);

COPY raw_data.sales (
    id,
    auto,
    gasoline_consumption,
    price,
    date,
    person_name,
    phone,
    discount,
    brand_origin
)
from 'D:\ITMO\ITMO-YANDEX-MASTERS\Databases\project-1\cars.csv'
with (
    format csv,
    header true,
    delimiter ',',
    null 'null'
);

create schema car_shop;

create table car_shop.country (
	id serial primary key, -- serial для автоинкремента
	name varchar(60) -- названия стран имеют переменную длину. Нет страны, название которой превышает 60 символов
);

create table car_shop.brand (
	id serial primary key, -- serial для автоинкремента
	name text unique not null, -- длина названия бренда не фиксируется жёстко
	origin_id integer references car_shop.country -- для связи со страной по PK, serial фактически является integer
);

create table car_shop.model (
	id serial primary key, -- serial для автоинкремента
	name text not null, -- названия моделей имеют переменную длину
	brand_id integer references car_shop.brand, -- для связи с брендом машины по PK, serial фактически является integer
	unique (brand_id, name) -- связка модель-бренд должна быть уникальной
);

create table car_shop.color (
	id serial primary key, -- serial для автоинкремента
	name text  unique not null -- названия цветов могут иметь разную длину
);

create table car_shop.customer (
	id serial primary key, -- serial для автоинкремента
	name text not null, -- имена клиентов имеют переменную длину. Может повторяться (владеет несколькими авто).
	phone varchar(30) not null -- Может повторяться. Содержит цифры и символы. 30 символов достаточно с запасом
);

create table car_shop.sales (
	id serial primary key, -- serial для автоинкремента
	customer_id integer not null references car_shop.customer, -- для связи с владельцем машины по PK, serial фактически является integer
	model_id integer not null references car_shop.model, -- для связи с моделью машины по PK, serial фактически является integer
	color_id integer not null references car_shop.color, -- для связи с цветом машины по PK, serial фактически является integer
 	gasoline_consumption numeric(3, 1) check (gasoline_consumption > 0), -- расход топлива может быть дробным и требует точного хранения. Целая часть не превышает двузначного числа. Дробная часть включает только десятые доли.
	price numeric(12, 2) not null check (price > 0), -- цена является денежным значением и не должна страдать от ошибок округления. (12,2) поддерживает цены с копейками в широком диапазоне. Не может быть null, должна быть больше 0
	date date not null, -- дата сделки, без указания времени 
	discount smallint default 0 check (discount between 0 and 100) -- число помещается в наименьший числовой тип. Может быть от 0 до 100
);

insert into car_shop.country (name) 
select distinct brand_origin 
from raw_data.sales
where brand_origin is not null;

insert into car_shop.brand (name, origin_id)
select distinct split_part(auto, ' ', 1), car_shop.country.id 
from raw_data.sales
left join car_shop.country 
on raw_data.sales.brand_origin = car_shop.country.name;

insert into car_shop.model (name, brand_id)
select distinct (substring(split_part(auto, ',', 1) from ' (.+)')), brand.id
from raw_data.sales
left join car_shop.brand as brand
on brand.name = split_part(auto, ' ', 1);

insert into car_shop.color (name)
select distinct split_part(auto, ',', 2) from raw_data.sales;

insert into car_shop.customer (name, phone)
select distinct person_name, phone from raw_data.sales;

insert into car_shop.sales (
    id,
    customer_id,
    model_id,
    color_id,
    gasoline_consumption,
    price,
    date,
    discount
)
select
    r.id,
    customer.id,
    model.id,
    color.id,
    r.gasoline_consumption,
    r.price,
    r.date,
    r.discount
from raw_data.sales r
join car_shop.customer customer
on customer.name = r.person_name and customer.phone = r.phone
join car_shop.model model
on model.name = substring(split_part(r.auto, ',', 1)from ' (.+)')
and model.brand_id = (
	select brand.id
		from car_shop.brand brand
		where brand.name = split_part(r.auto, ' ', 1)
	)
join car_shop.color color
on color.name = split_part(r.auto, ',', 2);

-- -- 1. Напишите запрос, который выведет процент моделей машин, у которых нет параметра gasoline_consumption.
select count(distinct model_id) filter (where gasoline_consumption is null) * 100.0 / count(distinct model_id) as result from car_shop.sales;

-- -- 2. Напишите запрос, который покажет название бренда и среднюю цену его автомобилей в разбивке по всем годам с учётом скидки.
-- -- Итоговый результат отсортируйте по названию бренда и году в восходящем порядке. Среднюю цену округлите до второго знака после запятой.
select
	brand.name as brand_name,
    date_part('year', sales.date) as year,
    round(avg(sales.price), 2) as price_avg
from car_shop.sales sales
join car_shop.model model on sales.model_id = model.id
join car_shop.brand brand on model.brand_id = brand.id
group by date_part('year', sales.date), brand_name order by brand_name, year;

-- -- 3. Посчитайте среднюю цену всех автомобилей с разбивкой по месяцам в 2022 году с учётом скидки.
-- -- Результат отсортируйте по месяцам в восходящем порядке. Среднюю цену округлите до второго знака после запятой.
select
    date_part('month', sales.date) as month,
	date_part('year', sales.date) as year,
    round(avg(sales.price), 2) as price_avg
from car_shop.sales sales 
join car_shop.model model on sales.model_id = model.id
where date_part('year', sales.date) = 2022
group by date_part('month', sales.date), year order by month;

-- -- 4.Используя функцию STRING_AGG, напишите запрос, который выведет список купленных машин у каждого пользователя через запятую.
-- -- Пользователь может купить две одинаковые машины — это нормально. Название машины покажите полное, с названием бренда — например:
-- -- Tesla Model 3. Отсортируйте по имени пользователя в восходящем порядке. Сортировка внутри самой строки с машинами не нужна.
select 
	customer.name as person,
	STRING_AGG(brand.name || ' ' || model.name, ', ') as cars
from car_shop.customer customer
join car_shop.sales sales on sales.customer_id = customer.id
join car_shop.model model on sales.model_id = model.id
join car_shop.brand brand on model.brand_id = brand.id
group by person
order by person desc;

-- -- 5. Напишите запрос, который вернёт самую большую и самую маленькую цену продажи автомобиля с разбивкой по стране без учёта скидки.
-- -- Цена в колонке price дана с учётом скидки.
select
    country.name as brand_origin,
    round(min(sales.price / (1 - sales.discount / 100.0)), 2) as price_min,
    round(max(sales.price / (1 - sales.discount / 100.0)), 2) as price_max
from car_shop.sales sales
join car_shop.model model on sales.model_id = model.id
join car_shop.brand brand on model.brand_id = brand.id
join car_shop.country country on brand.origin_id = country.id
where brand.origin_id is not null
group by brand_origin;

-- -- 6. Напишите запрос, который покажет количество всех пользователей из США. Это пользователи, у которых номер телефона начинается на +1.
select count(*) from car_shop.customer where phone like '+1%';