# asker_deploy

Ce projet permet de déployer une instance d'asker fonctionnelle dans un
environnement Docker. Il utilise les logiciels *MariaDB*, *Nginx*, *FPM* et *PhpMyAdmin*.

## Pré requis

Pour que l'installation fonctionne, vous devez installer **docker** et la commande
**docker compose**. Pour installer docker:
**Ubuntu**:
    apt-get install docker.io
**Fedora**:
    dnf install docker-ce


Si votre version de `docker` est récente, l'installation ajoute la commande
`docker compse`. Sinon, il est nécessaire d'installer `docker-compose` manuellement
[avec l'aide de la documentation suivante](https://docs.docker.com/compose/install/linux/#install-the-plugin-manually).

## Installation

Pour commencer l'installation, il vous suffit d'éxecuter le script d'installation:

    bash install.sh

Le script télécharge le repository contenant le code dans le dossier **asker**,
charge un backup de la database si présent dans le dossier `bootstrap`, puis installe les
vendors Symfony. Il offre la possibilité d'ajouter un utilisateur de développement `asker.dev`
avec les droits `admin`.

Une fois l'installation terminée vous pouvez y accéder [ici](http://127.0.0.1/app_dev.php).

Vous pouvez utiliser [phpMyAdmin](http://127.0.0.1:8080) pour gérer votre database.


## Authentification

L'authentification LDAP fonctionnera uniquement si vous êtes sur le réseau de l'université.
Si ce n'est pas le cas, vous pouvez utiliser uniquement les comptes qui commencent par **ext**
ou le compte `asker.dev`.

## Quelques commandes

Mettre à jour la database:

    docker exec asker_deploy_app_1 php bin/console doctrine:schema:update -f

Vider le cache:

    docker exec asker_deploy_app_1 php bin/console cache:clear --env=dev

Arrêter les containers:

    docker compose down

Démarrer les containers:

    docke -compose up -d
 
## MAJ asker_deploy en production
cd asker_deploy  
docker-compose down  
cd ..  
mv asker_deploy old_deploy  
git clone https://forge.univ-lyon1.fr/romain.chanu/asker_deploy.git  
cp old_deploy/.env asker_deploy  
cp old_deploy/jwtRS256.key asker_deploy/  
 cp last backup  
cd asker_deploy  
bash install.sh  
docker-compose down  
modifier la conf du service web  
```
        networks:
            - asker_net
        build: ./nginx
        ports:
            - "443:443"
        volumes:
            - ./nginx/default:/etc/nginx/sites-available/default
            - ./asker/:/var/www/html/
            - /etc/apache2/private/:/etc/apache2/private/
        depends_on:
            - app
        restart: ${RESTART}

```
cp old_deploy/nginx/default asker_deploy/nginx/ 
cp -r old_deploy/asker/web/uploads/ asker_deploy/asker/web/  
cd asker_deploy  
docker-compose up -d  



