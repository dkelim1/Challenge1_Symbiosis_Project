#!/bin/bash

set -x
yum update -y
yum install -y git mysql telnet


cat << EOF > /tmp/schema.sql

-- create database symbiosdb;

use symbiosdb;

CREATE TABLE IF NOT EXISTS users (
id int(11) NOT NULL auto_increment,
name varchar(100) NOT NULL,
age int(3) NOT NULL,
email varchar(100) NOT NULL,
PRIMARY KEY (id)
);

EOF

ssh -N -L ${DB_PORT}:127.0.0.1:${DB_PORT} ${DB_USER}@${DB_HOST} &
mysql --host=${DB_HOST} --port=${DB_PORT} --user=${DB_USER} --password=${DB_PASSWD} < /tmp/schema.sql


mkdir /app
git clone https://github.com/dkelim1/nodejs-mysql-crud.git /app


curl -sL https://rpm.nodesource.com/setup_10.x | sudo bash -
yum install -y nodejs


cat << EOF > /app/config.js

var config = {
	database: {
		host:	  '${DB_HOST}', 	// database host
		user: 	  '${DB_USER}', 		// your database username
		password: '${DB_PASSWD}', 		// your database password
		port: 	  '${DB_PORT}', 		// default MySQL port
		db: 	  '${DB_NAME}' 		// your database name
	},
	server: {
		host: '*',
		port: '3000'
	}
}

module.exports = config

EOF

cd /app; node app.js &