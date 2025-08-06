# Project3

**Using Docker for Lago**

*Postgres*

Set up a Database (used postgres) on external machine

	>ssh ubuntu@......
	>sudo apt update
	>sudo apt install postgresql

 Switch to Postgres user and make a superuser

 	>sudo -u postgres psql -c "ALTER USER postgres WITH PASSWORD 'YourStrongPassword';"

Create a role and databse trhough Postgres

	>sudo -u postgres createuser --interactive   # enter: lago_user, no superuser, no createrole, no createdb
	>sudo -u postgres createdb --owner=lago_user lago

Change connections so that it can be connected to remotely

	>nano /etc/postgresql/14/main/postgresql.conf

 	listen_addresses = '*' #or whatever IP you want it to be 

Add a line

	>nano /etc/postgresql/14/main/pg_hba.conf

 	host    lago    lago_user   0.0.0.0/0    md5

Reload Postgresql so that the db comes up

	>sudo systemctl restart postgresql

*Setting up Lago through Docker*

Using [https://getlago.com/docs/guide/lago-self-hosted/docker](url)

One line command works for local etup, but it is hard to connect to external db

Using advanced commands

Make a directory to clone lago into

	> git clone https://github.com/getlago/lago.git
 
Go to lago folder

	>cd lago
 
Create .env document with a Lago private key

	>echo "LAGO_RSA_PRIVATE_KEY=\"`openssl genrsa 2048 | base64 | tr -d '\n'`\"" >> .env

Go into .env folder and add the path to external postgres database

	>nano .env

 Add 
 
	POSTGRES_HOST=(IP)3.22.xxxxx
 	POSTGRES_PORT=5432
  	POSTGRES_USER=lago
  	POSTGRES_PASSWORD=YourStrongPassword
  	POSTGRES_DB=lago

Save .env 

Make sure Gemfile has the necessary gems (annotaterb, etc.)

	> sudo apt install bundler

Bundler make this easy

(still trying to debug gems)
