# Exploration de Keda

Mon objectif est d'explorer Keda comme orchestrateur de mes Batches sur Kubernetes.

Keda est une solution de scaling en fonction d'autre chose que ce qu'est capable le Horizontal Pod Autoscaling : https://keda.sh/

On peut donc scale nos pods en fonction d'une quantité de lignes dans une table postgres par exemple ou encore en fonction d'un topic Kafka.
La liste est assez complète, je vous invite à consulter la liste des "scalers" ici : https://keda.sh/docs/2.3/scalers


## Pré-requis

Puisque je veux faire mes expériences uniquement en local afin de m'affranchir de tout provider et permettre au plus grand nombre reproduire cette exploration en local,
il nous faut installer toute une batterie d'outils pour mener à bien cette expérience.

Voici la liste des outils à installer :
- minikube : https://minikube.sigs.k8s.io/docs/start/
- kubectl : https://kubernetes.io/docs/tasks/tools
- helm : https://helm.sh/docs/intro/install/

Les docs d'installation étant ultra bien faites, je vous laisse explorer ces différentes ressources pour faire votre propre install.

### Quelques commandes utiles

#### Minikube

Lancer le cluster Kubernetes minikube :
```zsh
$ minikube start
😄  minikube v1.22.0 sur Darwin 11.5.1
✨  Utilisation du pilote docker basé sur le profil existant
👍  Démarrage du noeud de plan de contrôle minikube dans le cluster minikube
🚜  Extraction de l'image de base...
🔥  Création de docker container (CPUs=2, Memory=1987Mo) ...
🐳  Préparation de Kubernetes v1.21.2 sur Docker 20.10.7...
🔎  Vérification des composants Kubernetes...
    ▪ Utilisation de l'image kubernetesui/dashboard:v2.1.0
    ▪ Utilisation de l'image kubernetesui/metrics-scraper:v1.0.4
    ▪ Utilisation de l'image gcr.io/k8s-minikube/storage-provisioner:v5
🌟  Modules activés: storage-provisioner, default-storageclass, dashboard
🏄  Terminé ! kubectl est maintenant configuré pour utiliser "minikube" cluster et espace de noms "default" par défaut.
```

Lancer l'interface web :
```zsh
$ minikube dashboard
🤔  Vérification de l'état du tableau de bord...
🚀  Lancement du proxy...
🤔  Vérification de l'état du proxy...
🎉  Ouverture de http://127.0.0.1:51094/api/v1/namespaces/kubernetes-dashboard/services/http:kubernetes-dashboard:/proxy/ dans votre navigateur par défaut...
```

Arrêter minikube :
```zsh
$ minikube stop
✋  Nœud d'arrêt "minikube" ...
🛑  Mise hors tension du profil "minikube" via SSH…
🛑  1 nœud(s) arrêté(s).
```

#### Helm

Il est possible de lister l'ensemble des charts helm déployés sur notre cluster :
```zsh
$ helm list --all-namespaces
NAME            NAMESPACE               REVISION        UPDATED                                 STATUS          CHART                   APP VERSION
keda            keda                    1               2021-07-30 23:19:20.030734 +0200 CEST   deployed        keda-2.3.2              2.3.0      
my-release      keda-with-postgresql    1               2021-07-31 00:09:29.392879 +0200 CEST   deployed        postgresql-10.8.0       11.12.0    
```

#### Kubectl

Connaitre l'état globale du cluster Kubernetes :
```zsh
$ kubectl get all --all-namespaces
NAMESPACE              NAME                                             READY   STATUS    RESTARTS   AGE
kube-system            pod/coredns-558bd4d5db-7ghq5                     1/1     Running   1          63m
kube-system            pod/etcd-minikube                                1/1     Running   1          63m
kube-system            pod/kube-apiserver-minikube                      1/1     Running   1          63m
kube-system            pod/kube-controller-manager-minikube             1/1     Running   1          63m
kube-system            pod/kube-proxy-pf9bk                             1/1     Running   1          63m
kube-system            pod/kube-scheduler-minikube                      1/1     Running   1          63m
kube-system            pod/storage-provisioner                          1/1     Running   3          63m
kubernetes-dashboard   pod/dashboard-metrics-scraper-7976b667d4-gdl4k   1/1     Running   1          62m
kubernetes-dashboard   pod/kubernetes-dashboard-6fcdf4f6d-rwf29         1/1     Running   2          62m

NAMESPACE              NAME                                TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)                  AGE
default                service/kubernetes                  ClusterIP   10.96.0.1      <none>        443/TCP                  63m
kube-system            service/kube-dns                    ClusterIP   10.96.0.10     <none>        53/UDP,53/TCP,9153/TCP   63m
kubernetes-dashboard   service/dashboard-metrics-scraper   ClusterIP   10.110.8.49    <none>        8000/TCP                 62m
kubernetes-dashboard   service/kubernetes-dashboard        ClusterIP   10.96.228.58   <none>        80/TCP                   62m

NAMESPACE     NAME                        DESIRED   CURRENT   READY   UP-TO-DATE   AVAILABLE   NODE SELECTOR            AGE
kube-system   daemonset.apps/kube-proxy   1         1         1       1            1           kubernetes.io/os=linux   63m

NAMESPACE              NAME                                        READY   UP-TO-DATE   AVAILABLE   AGE
kube-system            deployment.apps/coredns                     1/1     1            1           63m
kubernetes-dashboard   deployment.apps/dashboard-metrics-scraper   1/1     1            1           62m
kubernetes-dashboard   deployment.apps/kubernetes-dashboard        1/1     1            1           62m

NAMESPACE              NAME                                                   DESIRED   CURRENT   READY   AGE
kube-system            replicaset.apps/coredns-558bd4d5db                     1         1         1       63m
kubernetes-dashboard   replicaset.apps/dashboard-metrics-scraper-7976b667d4   1         1         1       62m
kubernetes-dashboard   replicaset.apps/kubernetes-dashboard-6fcdf4f6d         1         1         1       62m
```


## Déploiement de Keda

On va commencer par déployer Keda sur notre cluster.

La documentation est là aussi assez bien faite avec des modes d'installation alternatifs sur base de helm, kubectl ou directement via le "Operator Hub" : https://keda.sh/docs/2.3/deploy/

Je fais le choix de helm pour pouvoir revenir en arrière si besoin pour recommencer :
```zsh
$ helm repo add kedacore https://kedacore.github.io/charts
"kedacore" has been added to your repositories

$ helm repo update
Hang tight while we grab the latest from your chart repositories...
...Successfully got an update from the "kedacore" chart repository
Update Complete. ⎈Happy Helming!⎈

$ kubectl create namespace keda
namespace/keda created

$ helm install keda kedacore/keda --namespace keda
NAME: keda
LAST DEPLOYED: Fri Jul 30 23:19:20 2021
NAMESPACE: keda
STATUS: deployed
REVISION: 1
TEST SUITE: None
```

Ok, il semblerait que tout ce soit bien passé, on va vérifier l'état du cluster pour comprendre ce qu'il s'est passé :
On constate un nouveau namespace nommé keda...
```zsh
$ kubectl get namespaces
NAME                   STATUS   AGE
default                Active   98m
keda                   Active   2m32s
kube-node-lease        Active   98m
kube-public            Active   98m
kube-system            Active   98m
kubernetes-dashboard   Active   97m
```
... Ainsi qu'un ensemble de composants installés à l'intérieur.
```zsh
$ kubectl get all --namespace keda
NAME                                                   READY   STATUS    RESTARTS   AGE
pod/keda-operator-7fc5699d47-q6zxj                     1/1     Running   0          6m40s
pod/keda-operator-metrics-apiserver-57fc85685f-pqfrd   1/1     Running   0          6m40s

NAME                                      TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)          AGE
service/keda-operator-metrics-apiserver   ClusterIP   10.109.12.30   <none>        443/TCP,80/TCP   6m40s

NAME                                              READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/keda-operator                     1/1     1            1           6m40s
deployment.apps/keda-operator-metrics-apiserver   1/1     1            1           6m40s

NAME                                                         DESIRED   CURRENT   READY   AGE
replicaset.apps/keda-operator-7fc5699d47                     1         1         1       6m40s
replicaset.apps/keda-operator-metrics-apiserver-57fc85685f   1         1         1       6m40s
```

Ces différents composants vont nous permettre de déployer de nouveau composants nommés [ScaledObject](https://keda.sh/docs/2.3/concepts/scaling-deployments/) et [ScaledJob](https://keda.sh/docs/2.3/concepts/scaling-jobs/) qui vont eux piloter l'autoscaling des pods qu'ils soient des "Deployments", des "StatefulSets", des "Custom Resources" ou des "Jobs".

Et celui qui nous intéresse aujourd'hui est l'autoscaling des "Jobs" pour pouvoir traiter potentiellement un nombre très variable de Batches en parallèle.

Petit commande bien utile pour débugger quand Keda n'arrive pas à faire son office :
```zsh
$ kubectl logs -f -n keda keda-operator-7fc5699d47-q6zxj -c keda-operator
```

## Passons aux choses sérieuses

Pour mon premier essaye avec Keda, je choisi d'utiliser le scaler PostgreSQL.
Je vais donc tout réaliser dans un namespace dédié :
```zsh
$ kubectl create namespace keda-with-postgresql
namespace/keda-with-postgresql created

$ kubectl config set-context --current --namespace keda-with-postgresql
Context "minikube" modified.
```

Tout le déroulement qui suit se fera depuis le dossier postgres-batch :
```zsh
$ cd postrgres-batch
```

### Déploiement de PostgreSQL sur mon cluster minikube

Je n'ai pas trop envie de me prendre la tête à tout écrire moi-même pour déployer PostgreSQL sur mon cluster donc je préfère passer par les charts helm de bitnami : https://github.com/bitnami/charts

```zsh
$ helm repo add bitnami https://charts.bitnami.com/bitnami
"bitnami" has been added to your repositories

$ helm install my-release bitnami/postgresql
NAME: my-release
LAST DEPLOYED: Sat Jul 31 00:09:29 2021
NAMESPACE: keda-with-postgresql
STATUS: deployed
REVISION: 1
TEST SUITE: None
NOTES:
** Please be patient while the chart is being deployed **

PostgreSQL can be accessed via port 5432 on the following DNS names from within your cluster:

    my-release-postgresql.keda-with-postgresql.svc.cluster.local - Read/Write connection

To get the password for "postgres" run:

    export POSTGRES_PASSWORD=$(kubectl get secret --namespace keda-with-postgresql my-release-postgresql -o jsonpath="{.data.postgresql-password}" | base64 --decode)

To connect to your database run the following command:

    kubectl run my-release-postgresql-client --rm --tty -i --restart='Never' --namespace keda-with-postgresql --image docker.io/bitnami/postgresql:11.12.0-debian-10-r44 --env="PGPASSWORD=$POSTGRES_PASSWORD" --command -- psql --host my-release-postgresql -U postgres -d postgres -p 5432

To connect to your database from outside the cluster execute the following commands:

    kubectl port-forward --namespace keda-with-postgresql svc/my-release-postgresql 5432:5432 &
    PGPASSWORD="$POSTGRES_PASSWORD" psql --host 127.0.0.1 -U postgres -d postgres -p 5432
```

Sympa le chart, il nous indique même comment on se connect à base données...

### Fabrication du batch

Pour l'exemple, on va faire un Job très simple.
Il aura la lourde tâche d'ajouter une ligne au status "RUNNING" dans une table `clap` de la base de données puis d'attendre pendant X temps puis de changer le status de cette ligne en "SUCCESS" comme pourrait le faire un batch classique.

Pour les besoins du test de Keda avec le Scaler PostgreSQL, je vais aussi créer une table `make_it_clap` pour "piloter" le scaling.
Elle contiendra une colonne `duration_seconds` qui permettra de spécifier le temps d'un `clap` pour bien voir le scaling se mettre en place.

Cette première version est disponible dans [v1/make-it-clap.sql](postgres-batch/scripts/v1/make-it-clap.sql).

Étant donné que je souhaite que tout se fasse en local, je ne veux pas avoir à push mon image docker sur une registry publique.
Pour éviter ça, il est possible de faire en sorte que notre shell pointe sur le deamon docker de minikube.
Aisni, lors d'un `docker build`, l'image résulante ira dans le cache locale de minikube, ce qui lui permettra d'utiliser l'image docker sans faire de pull.

Il faut donc executer les commandes suivantes :
```zsh
$ eval $(minikube docker-env)
$ docker build . -t postgres-batch:latest
```

Pour revenir au deamon docker local, executer simplement :
```zsh
$ eval $(minikube docker-env -u)
```

Voilà, notre image docker est maintenant accessible depuis minikube

### Test du batch

Pour tester ce batch, il faut :
- Insérer une ligne dans la table `make_it_clap` : `INSERT INTO make_it_clap (duration_seconds) VALUES (40);`
- Déployer manuellement le `Job` : `$ kubectl apply -f job.yaml`
- Vérifier que le job est en cours : `kubectl get jobs `
```
NAME             COMPLETIONS   DURATION   AGE
postgres-batch   0/1           12s        121m
```
- Vérifier que le job est terminé : `kubectl get jobs `
```
NAME             COMPLETIONS   DURATION   AGE
postgres-batch   1/1           42s        121m
```
- Controller que le batch s'est correctement déroulé : `SELECT * FROM clap;`
```
 id | status  | session_id | creation_date | creation_time   |    end_time
----+---------+------------+---------------+-----------------+-----------------
  1 | SUCCESS |   49918852 | 2021-08-02    | 12:10:23.14951  | 12:11:03.751734
(1 row)
```

## Passage à l'échelle avec Keda

Il est maintenant l'heure de faire passer notre Job à l'échelle en déléguant le pilotage du scaling à Keda.

Keda permet de piloter le nombre de `Jobs` à executer sur base d'une requête SQL executée à interval de temps régulier.

Voici le descripteur de `ScaledJob` utilisé ici dans notre cas :
```yaml
apiVersion: keda.sh/v1alpha1
kind: ScaledJob
metadata:
  namespace: keda-with-postgresql
  name: postgres-batch
spec:
  jobTargetRef:
    template:
      spec:
        containers:
          - name: postgres-batch
            image: postgres-batch:latest
            imagePullPolicy: Never
            env:
              - name: PG_HOST
                value: "my-release-postgresql"
              - name: PG_PORT
                value: "5432"
              - name: PG_USERNAME
                value: "postgres"
              - name: PGPASSWORD
                valueFrom:
                  secretKeyRef:
                    name: my-release-postgresql
                    key: postgresql-password
        restartPolicy: Never
    backoffLimit: 4
  pollingInterval: 30             # Optional. Default: 30 seconds
  maxReplicaCount: 10             # Optional. Default: 100
  successfulJobsHistoryLimit: 10  # Optional. Default: 100. How many completed jobs should be kept.
  failedJobsHistoryLimit: 5       # Optional. Default: 100. How many failed jobs should be kept.
  triggers:
    - type: postgresql
      metadata:
        userName: "postgres"
        passwordFromEnv: PGPASSWORD
        host: my-release-postgresql.keda-with-postgresql.svc.cluster.local #use the cluster-wide namespace as KEDA lives in a different namespace from your postgres
        port: "5432"
        dbName: postgres
        sslmode: disable
        query: "SELECT COUNT(1) FROM make_it_clap LEFT JOIN clap ON make_it_clap.id = clap.id WHERE clap.status IS NULL;"
        targetQueryValue: "1"
```

Toute la partie `spec.jobTargetRef.template` est strictement la même que dans `job.yaml` donc on n'est pas perdu.
En revanche, la suite nécessite une petite explication :
- `pollingInterval` : interval de temps entre 2 execution de la requête
- `maxReplicaCount` : nombre maximum de `Jobs` à lancer en parallèle
- `successfulJobsHistoryLimit` : nombre de `Jobs` en succès à garder dans l'historique
- `failedJobsHistoryLimit` : nombre de `Jobs` en en erreur à garder dans l'historique

l'élément le plus import de la partie `triggers` est la `query` qui servira à connaitre le nombre de `Jobs` à éxecuter en paralléle.

Dans notre exemple, chaque nouvelle ligne donnera naissance à un nouveau `Job` dans la limite de `maxReplicaCount`.
Si on voulait quelque chose de moins radicale, on pourrait diviser le résultat de la requête par un entier :
```SQL
SELECT ceil(COUNT(1)::decimal / 10) FROM make_it_clap LEFT JOIN clap ON make_it_clap.id = clap.id WHERE clap.status IS NULL;
```
Ce qui réduirait par 10 le nombre de `Jobs` en parallèle pour finir par les executer 1 à 1.

Comme d'habitude, on déploie le `ScaledJob` avec la commande :
```zsh
$ kubectl apply -f deploy/scaled-job.yaml
```

Ok, maintenant que le `ScaledJob` est déployé, le principe est plutôt simple, on doit insérer des lignes dans la table `make_it_clap` pour éxecuter les Jobs :
```SQL
-- répété 60 fois
INSERT INTO make_it_clap (duration_seconds) VALUES (40);
```

On peut surveiller l'évolution des `Jobs` :
```zsh
$ kubectl get jobs
NAME                   COMPLETIONS   DURATION   AGE
postgres-batch-292ng   0/1           8s         10s
postgres-batch-2cfnw   0/1           8s         10s
[...]
postgres-batch-zklk2   0/1           10s        10s
```

ainsi que celle des `claps` :
```SQL
postgres=# select * from clap;
 id | status  | session_id | creation_date |  creation_time  |    end_time
----+---------+------------+---------------+-----------------+-----------------
  1 | RUNNING |  333443748 | 2021-08-02    | 16:17:41.28766  |
  2 | RUNNING |  637700789 | 2021-08-02    | 16:17:46.266496 |
[...]
 30 | RUNNING |  752837758 | 2021-08-02    | 16:18:29.902603 |
```

Au bout d'un certain temps, on voit que de nouveaux `Jobs` prennent la suite quand les premiers `Jobs` se terminent :
```zsh
$ kubectl get jobs.batch
NAME                   COMPLETIONS   DURATION   AGE
postgres-batch-292ng   1/1           86s        96s
postgres-batch-2cfnw   1/1           88s        96s
postgres-batch-fbhfz   0/1           5s         5s
[...]
postgres-batch-4jtnn   0/1           65s        65s
postgres-batch-4nc8p   0/1           5s         5s
```

ainsi que les `claps` qui s'executent :
```SQL
select * from clap ORDER BY id;
 id | status  | session_id | creation_date |  creation_time  |    end_time
----+---------+------------+---------------+-----------------+-----------------
  1 | SUCCESS |  333443748 | 2021-08-02    | 16:17:41.28766  | 16:18:21.839829
  2 | SUCCESS |  637700789 | 2021-08-02    | 16:17:46.266496 | 16:18:27.084621
  3 | SUCCESS |   45350398 | 2021-08-02    | 16:17:47.881485 | 16:18:28.256152
[...]
 11 | RUNNING |  596834214 | 2021-08-02    | 16:17:53.469475 | 
 12 | RUNNING |  154339869 | 2021-08-02    | 16:17:53.566302 | 
[...]
 31 | RUNNING |  752837758 | 2021-08-02    | 16:18:54.986443 | 
```

OK, on voit que ça fonctionne plutôt bien, ce qui est une bonne chose, qu'on se le dise.


## Gestion de l'échec d'un `Job`

Je me demande maintenant comment on gère les échecs... Que se passe-t-il quand le `Job` est en échec ?
Dans la doc, il n'est pas indiqué qu'il faille faire quoi que ce soit pour gérer les échecs, seulement la propriété `backoffLimit` du kind `Job` de Kubernetes qui semble permettre le rejeu en cas d'erreur.

Voyons donc comment tout ça va se comporter en cas d'erreur.
Pour ce faire, je modifie un peu mes scripts :
- `make-it-clap.sql` pour enregistrer le `status` en fonction de la variable d'environnement `FINAL_STATE`
- `entrypoint.sh` pour faire échouer le `Job` en fonction de cette même variable d'environnement
- `scaled-job.yaml` pour set la variable d'environnement

Cette seconde version du batch est consultable dans [v2/make-it-clap.sql](postgres-batch/scripts/v2/make-it-clap.sql).

On relance le tout :
```zsh
$ docker build . -t postgres-batch:latest 
$ kubectl replace --force -f deploy/scaled-job.yaml
INSERT INTO make_it_clap (duration_seconds) VALUES (1);
```
Et là... c'est le drame !

Le job se relance bien comme indiqué par la propriété `.spec.jobTargetRef.template.spec.backoffLimit` :
```zsh
$ kubectl describe jobs.batch postgres-batch-vqhs7
Events:
  Type     Reason                Age   From            Message
  ----     ------                ----  ----            -------
  Normal   SuccessfulCreate      16m   job-controller  Created pod: postgres-batch-vqhs7-8p7nx
  Normal   SuccessfulCreate      16m   job-controller  Created pod: postgres-batch-vqhs7-mf4z9
  Normal   SuccessfulCreate      15m   job-controller  Created pod: postgres-batch-vqhs7-4cwdz
  Normal   SuccessfulCreate      15m   job-controller  Created pod: postgres-batch-vqhs7-cg48m
  Normal   SuccessfulCreate      14m   job-controller  Created pod: postgres-batch-vqhs7-tbfjc
  Warning  BackoffLimitExceeded  13m   job-controller  Job has reached the specified backoff limit
```
Mais il y a un "mais"... le job ne prend le `clap` à effectuer qu'une seule fois lors de la première tentative d'execution du pod :

Première tentative :
```zsh
$ kubectl logs postgres-batch-vqhs7-8p7nx 
Running the sql script
[...]
 id | duration_seconds | id | status | session_id | creation_date | creation_time | end_time 
----+------------------+----+--------+------------+---------------+---------------+----------
  3 |                1 |    |        |            |               |               | 
(1 row)
[...]
UPDATE 1
Everything's failed
```

Seconde tentative :
```zsh
$ kubectl logs postgres-batch-vqhs7-mf4z9 
Running the sql script
[...]
 id | duration_seconds | id | status | session_id | creation_date | creation_time | end_time 
----+------------------+----+--------+------------+---------------+---------------+----------
(0 rows)
[...]
UPDATE 0
Everything's failed
```

Il faudrait donc que le batch soit fault-tolerant afin de reprendre le `clap` ayant échoué 🤔.

La première solution qui me vient en tête est de modifier la requête de pilotage du scaling pour inclure les `claps` au status `FAILED` mais cela risque fort d'engendrer un scaling infinie si le `clap` ne passe jamais à `SUCCESS` pour quelque raison que ce soit.
Ce qui, vous le conviendrait, serait une petite cata pour nos amis les FinOps.

Une approche trop simpliste pourrait également rendre le debugging (en phase de RUN) très complexe car un `Job` pourrait se mettre à traiter des `claps` différents entre 2 retry.

Je ne sais pas si c'est la meilleure des solutions, mais c'est une solution qui a fonctionnée dans le cas d'un script PostgreSQL relativement simple.
Je n'ai finalement pas modifié la requête SQL de pilotage du scaling mais j'ai pas mal modifié le script sql pour affecter le nom du `Job` au `clap` à traiter, ainsi d'un retry à l'autre, ce sera le même `clap` qui sera effectué pour un `Job` donné.

Et pour bien voir les changements de status, le script échouera les 3 premières fois pour ensuite aboutir la 4ème fois.

On re-relance le tout :
```zsh
$ docker build . -t postgres-batch:latest 
$ kubectl replace --force -f deploy/scaled-job.yaml
INSERT INTO make_it_clap (duration_seconds) VALUES (10);
```

on scrute la création des pods :
```zsh
$ kubectl get pods
NAME                           READY   STATUS      RESTARTS   AGE
my-release-postgresql-0        1/1     Running     0          3h12m
my-release-postgresql-client   1/1     Running     0          97m
postgres-batch-mqmg7-6d7bb     0/1     Error       0          48s
postgres-batch-mqmg7-gsj54     0/1     Error       0          81s
postgres-batch-mqmg7-h2z24     0/1     Error       0          69s
postgres-batch-mqmg7-v9hqc     0/1     Completed   0          28s
```
Et on voit que 3 tentatives sont en erreur alors que la 4éme s'est passée correctement.

En scrutant les `claps` dans postgres pendant l'execution, on voit les changements de status ainsi que le nombre d'itérations se mettre à jour :
```zsh
postgres=# select * from clap;
 id | status  | session_id | creation_date | creation_time  |    end_time     | iteration
----+---------+------------+---------------+----------------+-----------------+-----------
  1 | FAILED  |  650018425 | 2021-08-04    | 01:53:09.68744 | 01:53:19.693264 |         1
(1 row)
...
  1 | RUNNING |   14628382 | 2021-08-04    | 01:53:09.68744 | 01:53:19.693264 |         1
(1 row)
...
  1 | FAILED  |   14628382 | 2021-08-04    | 01:53:09.68744 | 01:53:31.482351 |         2
(1 row)
...
  1 | RUNNING |   66819766 | 2021-08-04    | 01:53:09.68744 | 01:53:31.482351 |         2
(1 row)
...
  1 | FAILED  |   66819766 | 2021-08-04    | 01:53:09.68744 | 01:53:52.541976 |         3
(1 row)
...
  1 | RUNNING |  799850712 | 2021-08-04    | 01:53:09.68744 | 01:53:52.541976 |         3
(1 row)
...
  1 | SUCCESS |  799850712 | 2021-08-04    | 01:53:09.68744 | 01:54:12.601349 |         4
(1 row)
```

Pour être tout à fait honnête, je ne suis pas vraiment satisfait de la solution finale qui consiste à mettre le nom du `Job` dans la table `make-it-clap`.

## Conclusion

Biensur, je n'ai exploré là que la partie batch sur base du Scaler PostgreSQL et il est possible de scale d'autres composants Kubernetes en utilisant d'autres Scalers, 
mais Keda semble déjà être une bonne solution de scaling en fonction de métrique autre que les CPU et autre consommation mémoire.
Il vient avec son lot de contraintes mais elles sont surmontables et surtout incontournables quand on conçoit un tel système tolérant aux pannes.
Il faut toujours garder en tête que certaines taches risquent d'échouer en concidérant qu'elles vont échouer à coup sûr.

Le fait de tout devoir gérer manuellement pour rendre les Jobs tolérants aux pannes est très probablement dû au fait que je me soit limité à utiliser des scripts SQL pour faire simple.
Je suis convaincu qu'en utilisant des outils/frameworks, comme Spring Batch par exemple, tout se passerait beaucoup mieux.

Je ferais dans un prochain billet la même experience avec ce framework pour challenger cette conclusion.


.

.

.

.

.

.

.

.

.

.

.

.

.

.

.

