# Project3
Project 3 for internship

**Using Docker for Lago**

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
