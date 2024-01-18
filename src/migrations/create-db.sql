create database if not exists finances;

use finances;

CREATE TABLE if not exists users (
   id BIGINT AUTO_INCREMENT PRIMARY KEY,
   name VARCHAR(255) NOT NULL,
   login VARCHAR(50) UNIQUE NOT NULL,
   password VARCHAR(255) NOT NULL,
   status ENUM('active', 'inactive') NOT NULL,
   created_at TIMESTAMP NOT NULL,
   updated_at TIMESTAMP
);
