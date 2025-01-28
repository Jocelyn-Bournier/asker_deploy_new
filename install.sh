#!/bin/bash
LINE=0
PREVIOUS=0
COUNTER=0
#UNAME=$(uname -s)
COMPOSE=0
FAIL=0
SSH=0
DOUA=0
PROXY=0
DEVUSER=0
NODUMP=0

function check_proxy_env(){
        cat .env | grep "PROXY" > /dev/null 2>&1
        echo $?
}

# Section Check

# Check if docker in PATH
type docker > /dev/null 2>&1
if [[ $? -eq 1 ]]; then
        echo "Docker is not installed. Please install it first."
        echo "Ubuntu: apt-get install docker.io"
        echo "Fedora: dnf install docker-ce"
        exit 1
fi


# Check if docker-compose in PATH. Install for linux
type docker-compose > /dev/null 2>&1
if [[ $? -eq 1 ]]; then
        type docker compose version > /dev/null 2>&1
        if [[ $? -ne 1 ]]; then
                echo -n "This installer requires `docker compose` and no longer performs the installation itself."
                exit 1
        fi
        echo "Using docker compose"
        BINARY="docker compose"
else
        echo "Using docker-compose"
        BINARY="docker-compose"
fi
# Check if docker is running
docker ps > /dev/null 2>&1
if [[ $? -eq 1 ]]; then
        echo "Docker is not running. Start it!"
        exit 1
fi

# Am i running in Doua's network
timeout 3 bash -c 'cat < /dev/null > /dev/tcp/proxy.univ-lyon1.fr/3128'
if [  $? -eq 0 ]; then
        DOUA=1
fi

# EndSection


# Section Configuration


if [[ ! -f ".env" ]]; then
        # Prompt to create devuser
        while true; do
            read -p "Do you want to create a devuser? [yes/no]" yn
            case $yn in
                [Yy]es) DEVUSER=1; break;;
                [Nn]o) break;;
                * ) echo -e "Please answer yes or no.\n";;
            esac
        done

        # Do you have any dump to use
        if ! find bootstrap/ -type f -name "*.sql" | grep -q . ;then
                echo -n "
No SQL dumps were found to process. If you have one, stop the installer,
place the dump file in the bootstrap directory, and restart the process.
If not, simply answer 'yes' to the next question when prompted.
"
                while true; do
                    read -p "Do you want to continue? [yes/no]" yn
                    case $yn in
                        [Yy]es) NODUMP=1; break;;
                        [Nn]o) exit 1;;
                        * ) echo "Please answer yes or no.";;
                    esac
                done
        fi

        # Prompt database variables
        echo "Set MYSQL ROOT PASSWORD:"
        read -s MYSQL_ROOT_PASSWORD
        echo "Set MYSQL APP PASSWORD:"
        read -s MYSQL_PASSWORD
        echo "Set MYSQL USER:"
        read -s MYSQL_USER
        echo "Set MYSQL DATABASE:"
        read -s MYSQL_DATABASE
        echo "MYSQL_ROOT_PASSWORD=$MYSQL_ROOT_PASSWORD
MYSQL_PASSWORD=$MYSQL_PASSWORD
MYSQL_USER=$MYSQL_USER
MYSQL_DATABASE=$MYSQL_DATABASE
DEVUSER=$DEVUSER
RESTART=no" > .env
else
        source .env
fi

# EndSection



# get code
if [ ! -d asker ];then
        echo -n "
Cloning the asker repository from forge.univ-lyon1.fr.
The default behavior uses HTTPS. If you wish to use SSH, answer 'no' to the next question.
If you are unsure whether you have SSH access, answer 'yes'
"
        while true; do
            read -p "Do you wish to use HTTPS for cloning? [yes/no]" yn
            case $yn in
                [Yy]es) SSH=0;break;;
                [Nn]o) SSH=1;break;;
                * ) echo "Please answer yes or no.";;
            esac
        done
        if [ $SSH -eq 1 ];then
                git clone git@forge.univ-lyon1.fr:asker/asker.git
        else
                git clone -b master https://github.com/Jocelyn-Bournier/asker_with_traces_trackers.git
                mv ./asker_with_traces_trackers ./asker
        fi
fi


# integration comper
if [ -f jwtRS256.key ];then
        cp jwtRS256.key asker/app/config/
else
        echo "" >  asker/app/config/jwtRS256.key
fi
if [ -f comper_secrets.yml ];then
        cp comper_secrets.yml asker/app/config/
else
        echo "
parameters:
    comper_lrs_creds: comper_to_trax_password
" > asker/app/config/comper_secrets.yml
fi
if [ -f ldap_secrets.yml ];then
        cp ldap_secrets.yml asker/src/CRT/LdapBundle/Resources/config/
else
        echo "
parameters:
    ldap_server.bindPassword: \"unmauvaispassword\"
    ref_password: \"unmauvaispassword\"" > asker/src/CRT/LdapBundle/Resources/config/ldap_secrets.yml

fi

# unchange release files // another way to do it?
cd asker
bash new_assets_release.sh
cd ..
$BINARY down > /dev/null 2>&1

# build all images then start in background
# add test if  PROXY already exist in file
if [ $DOUA -eq 0 ];then
        if [ $(check_proxy_env) -eq 1 ]; then
                echo "PROXY=0">> .env
        fi
        $BINARY build
else
        if [ $(check_proxy_env) -eq 1 ]; then
                echo "PROXY=1">> .env
        fi
        $BINARY build --build-arg PROXY=1 --build-arg http_proxy=http://proxy.univ-lyon1.fr:3128 --build-arg https_proxy=http://proxy.univ-lyon1.fr:3128
fi



$BINARY up -d


# DL vendors
echo -n "Symfony is installing..."
function check_ready () {
        $BINARY logs app | grep ready > /dev/null 2>&1
        echo $?

}
RET=$(check_ready)
while [[ $RET -eq 1 && $FAIL -eq 0 ]] ; do
    sleep 10
    echo -n "."
    LINE=$($BINARY logs app | wc -l)
    if [ $LINE -gt $PREVIOUS ]; then
        echo -n "."
        PREVIOUS=$LINE
    else
        COUNTER=`expr $COUNTER + 1`
    fi
    if [ $COUNTER -gt 60 ]; then
        >&2 echo "We have been waiting for too long. Installation failed."
        FAIL=1
    fi;
    RET=$(check_ready)
done

# put variables in Symfony's parameters. After vendors cause it erases this file
$BINARY exec app bash -c 'echo "parameters:
    database_host: db
    database_port: null
    database_name: $MYSQL_DATABASE
    database_user: $MYSQL_USER
    database_password: $MYSQL_PASSWORD
    mailer_transport: smtp
    mailer_host: 127.0.0.1
    mailer_user: null
    mailer_password: null
    secret: ThisTokenIsNotSoSecretChangeIt" > app/config/parameters.yml'

echo  -e "\nVerifiying if mysqld is alive. This step takes around 60 seconds"
while ! $BINARY exec db mysqladmin ping -h db -u $MYSQL_USER -p$MYSQL_PASSWORD --silent; do
        sleep 10 #increase to 10 to reduce output
        echo "Waiting for MySQL"
done
# create interaction_traces table
docker exect -it asker_deploy_new-db-1 mysql -p$MYSQL_PASSWORD -u $MYSQL_USER $MYSQL_DATABASE -e "CREATE TABLE interaction_traces (id INT AUTO_INCREMENT PRIMARY KEY, user_id INT NOT NULL, type VARCHAR(128) NOT NULL, dd DATETIME NOT NULL, df DATETIME NOT NULL, content JSON NOT NULL, context JSON NOT NULL);"

$BINARY exec app php bin/console doctrine:schema:update -f
# while is_visible not implemented in model
docker exec -it asker_deploy_new-db-1 mysql -p$MYSQL_PASSWORD -u $MYSQL_USER $MYSQL_DATABASE -e "alter table directories_models add column visible boolean"
docker exec -it asker_deploy_new-db-1 mysql -p$MYSQL_PASSWORD -u $MYSQL_USER $MYSQL_DATABASE -e "update directories_models set visible  = 1"


# If no dump we have to create default roles
if [[ $NODUMP -eq 1 ]]; then
                echo "Create roles into $MYSQL_DATABASE"
docker exec -it asker_deploy_new-db-1 mysql -p$MYSQL_PASSWORD -u $MYSQL_USER $MYSQL_DATABASE -e " select * from role"
        docker exec -it asker_deploy_new-db-1 mysql -p$MYSQL_PASSWORD -u $MYSQL_USER $MYSQL_DATABASE -e "insert into role  values (1,'ROLE_USER','Utilisateur');"
        docker exec -it asker_deploy_new-db-1 mysql -p$MYSQL_PASSWORD -u $MYSQL_USER $MYSQL_DATABASE -e "insert into role  values (2,'ROLE_WS_CREATOR','Enseignant');"
        docker exec -it asker_deploy_new-db-1 mysql -p$MYSQL_PASSWORD -u $MYSQL_USER $MYSQL_DATABASE -e "insert into role  values (3,'ROLE_ADMIN','Admin');"
fi
# Create devuser
if [ $DEVUSER -eq 1 ]; then
        docker exec -it asker_deploy_new-db-1 mysql -p$MYSQL_PASSWORD -u $MYSQL_USER $MYSQL_DATABASE -e "insert into asker_user (username, firstName, lastName, password, isEnable,salt,ldapEmployeeId,isLdap) values ('asker.dev','asker','dev','\$2y\$10\$BQvE0DlJmuFZPHEz4RJehO71ZFUfYa7PLFudpateLwmpca1eaBENu',1,'5e8ddfe456d95',0,0);"
        docker exec -it asker_deploy_new-db-1 mysql -p$MYSQL_PASSWORD -u $MYSQL_USER $MYSQL_DATABASE -e "insert into asker_user_role  (asker_user_id, role_id) values ((select id from asker_user where username = 'asker.dev'), 1);"
        docker exec -it asker_deploy_new-db-1 mysql -p$MYSQL_PASSWORD -u $MYSQL_USER $MYSQL_DATABASE -e "insert into asker_user_role  (asker_user_id, role_id) values ((select id from asker_user where username = 'asker.dev'), 2);"
        docker exec -it asker_deploy_new-db-1 mysql -p$MYSQL_PASSWORD -u $MYSQL_USER $MYSQL_DATABASE -e "insert into asker_user_role  (asker_user_id, role_id) values ((select id from asker_user where username = 'asker.dev'), 3);"

        if [[ $? -eq 1 ]]; then
                FAIL=1
        fi
fi


#Create git hook to update buildVersion
#cp pre-commit asker/.git/hooks/pre-commit
#if [[ $? -eq 1 ]]; then
#        FAIL=1
#fi
#chmod u+x asker/.git/hooks/pre-commit
#if [[ $? -eq 1 ]]; then
#        FAIL=1
#fi

if [[ $FAIL -eq 1 ]]; then
        echo  -e "\n\e[41m\e[30mInstall failed\033[0m"
else
        echo  -e "\n\e[42m\e[30mInstall was successful\033[0m"
        echo "URL: http://127.0.0.1/app_dev.php"
        echo "phpMYAdmin: http://127.0.0.1/phpmyadmin/index.php"
        echo "login is asker.dev password is 'askerdev'"
fi



