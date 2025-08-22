# Project3

**Docker**

Docker is a service that lets you not worry about the environment that you set up containers in.

It builds an environment based on a Dockerfile that you provide (or get from someone to run their program on) so that compatability issues dont occur.

Dockerfiles provide information for Docker to build envronments and they usually include things like 

	FROM <image> - includes the image that the build extends on
 	WORKDIR <path> - specifies the place that the commands will be copied to and ran
  	COPY <host-path> <image-path> - tells the builder to copy files from the host and puts them in the image path
   	RUN <commands> - tells the builder to run a command
	ENV <name> <value> - sets a environment variable for the container to use
 	EXPOSE <port-number> - exposes a port
  	USER <user-or-uid> - sets user
   	CMD ["<command>", "<arg1>"] - the default command a container using this image will run

Docker compose, usually in a YML file is used to define and run multi-container applications, like for Lago.

**Kubernetes**

Kubernetes is used to manage containers to bundle and run applications

It can expose ports and manage traffic to different containers in order to keep the deployment stable

Automatically rolls out and maintains containers so that you can have your wanted amount at all times 
	If a container fails, it recreates it if it goes out and kills it if it doesnt respond

 You can launch a application through Docker and Kubernetes can help in hosting it or keep it up and healthy

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

**Gems**

Gems are bundles of Ruby (the langauge) that certain deployments may need to run.

Use Bundler to install gems directly, or add gems to a Gemfile so that it can be installed when the build goes up


	>source "https://rubygems.org"
	>git_source(:github) { |repo| "https://github.com/#{repo}.git" }

	>ruby <ruby version x.x.x>

  	>group <group> (optional)
	>gem '<gem>'
 	>end (if used group)

^ The contents of a Gemfile

Using 

	>sudo bundle install

Will install the Gems listed in the Gemfile

Gems are also used in Dockerfiles an will be active once you try to deploy containers

You can do this by putting them into RUN or CMD command inside a Dockerfile.

^this is whats giving me trouble since I cannot locate where annotate_rb is and why its stopping the lago_api container from running

*tried*
Changing dockerfile
updating ruby (probably did not work since it depends on container version and not host version)
making a lib/tasks folder to not require annotate
looking through docker-compose.yml
adding all dependencies
adding annotate_rb mannually
adding gems similar in name to annotate_rb


(still trying to debug gems)
