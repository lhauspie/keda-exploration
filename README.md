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

Petite commande bien utile pour débugger quand Keda n'arrive pas à faire son office :
```zsh
$ kubectl logs -f -n keda keda-operator-7fc5699d47-q6zxj -c keda-operator
```

## Et maintenant ?

J'ai rédigé une suite de docs pour chaque exploration :
- [Batch purement SQL sur base du Scaler PostgreSQL](postgres-sql-batch/README.md)
- [Batch Spring Batch sur base du Scaler PostgreSQL](postgres-spring-batch/README.md)
- [Batch Spring Batch sur base du Scaler kafka](postgres-kafka-batch/README.md)
- 