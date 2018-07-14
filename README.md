# Chat

## Getting started

### Installation
 
#### Installing Elixir 1.4 or later

##### Debian/Ubuntu
Users of Debian based systems needs to install Erlang/OTP first and then install Elixir.
````
# Add Erlang repository  
$ wget https://packages.erlang-solutions.com/erlang-solutions_1.0_all.deb
$ sudo dpkg -i erlang-solutions_1.0_all.deb

# Install Erlang
$ sudo apt-get update
$ sudo apt-get install esl-erlang

# Install Elixir
$ sudo apt-get install elixir
````

##### macOS
````
$ brew install elixir
````
If you don't have Homebrew installed follow [instructions here.](https://brew.sh/index.html)

##### Fedora 21 and older
````
$ sudo yum install elixir
````

##### Fedora 22 and newer
````
$ sudo dnf install elixir
````

#### Install node.js 5.0.0 or later

##### Debian/Ubuntu
````
$ curl -sL https://deb.nodesource.com/setup_8.x | sudo -E bash -
$ sudo apt-get install nodejs
````

##### macOS
````
$ brew install 
````

##### Fedora 21 and older
````
$ curl --silent --location https://rpm.nodesource.com/setup_8.x | sudo bash -
$ sudo yum install nodejs
````

##### Fedora 22 and newer
````
$ sudo dnf install nodejs
````

#### Installing Phoenix Framework
Check if you have Erlang 18 or later and Elixir 1.4 or later:
````
$ elixir -v

Erlang/OTP 20 [erts-9.1.2] [source] [64-bit] [smp:8:8] [ds:8:8:10] [async-threads:10] [hipe] [kernel-poll:false] [dtrace]

Elixir 1.5.2
````
Install Hex or upgrade to the latest version if you have Hex already installed:
````
$ mix local.hex
````
Install Phoenix archive:
````
$ mix archive.install https://github.com/phoenixframework/archives/raw/master/phx_new.ez
````

### Database and JWT configuration
Before starting server you need to configure database. To do that first you need to create `config/dev.secret.exs` file and store there database and JWT configuration.
Example:
````
use Mix.Config

config :chat, Chat.Repo,
       adapter: Ecto.Adapters.Postgres,
       username: "postgres",
       password: "postgres",
       database: "chat_dev",
       hostname: "localhost",
       pool_size: 10

config :chat, :google_client_id, "541559570744-8pit96qa2ag80asj2btdqo5dq4j0l2eo.apps.googleusercontent.com"
````
By default project uses PostgreSQL as database, if you intend to change it you need to add dependency for adapter to `mix.exs` file and then run
````
$ mix deps.get
````
You can find supported databases [here.](https://github.com/elixir-ecto/ecto#usage)

### Running tests
To run tests simply use `mix test` command.
More information about tests you can find [here.](https://hexdocs.pm/phoenix/testing.html)

### Running server
````
# Install needed dependecies
$ mix deps.get

# Create and migrate database
$ mix ecto.create
$ mix ecto.migrate 

# Install Node.js dependencies
$ cd assets
$ npm install
$ cd ..

# Start Phoenix server
$ mix phx.server
````

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.


## Built With
  * [Elixir](https://elixir-lang.org/) - Programing Language used
  * [Mix](https://elixir-lang.org/getting-started/mix-otp/introduction-to-mix.html) - Dependency Manager used
  * [Phoenix Framework](http://phoenixframework.org/) - MVC Web Framework used
  * [PostgreSQL](https://www.postgresql.org/) - Default database used
  
## More
  * Guides and Docs for Phoenix Framework: https://hexdocs.pm/phoenix/Phoenix.html
  * Guides and Docs for Ecto: https://hexdocs.pm/ecto/Ecto.html
  * Guide for Mix: https://elixir-lang.org/getting-started/mix-otp/introduction-to-mix.html
  * Guide for Elixir: https://elixir-lang.org/getting-started/introduction.html
  * PostgreSQL download: https://www.postgresql.org/download/
  * PhoenixJS client documentation: https://hexdocs.pm/phoenix/js/

Before first deployment master acts as development branch, not production one.