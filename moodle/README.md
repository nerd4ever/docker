# Moodle

Essa imagem usa o Moodle 4.0.1 (usado na época que foi criada) 
- PHP 7.4
- Apache

## Descrição

Essa imagem é permite usar Moodle com o banco de dados PostgreSQL ou MySQL.

## Usando em  docker-composer 

Exemplo usado para buildar a imagem e testar

````
version: "2.0"
services:
  db:
    image: postgres:14.1-alpine
    restart: always
    networks:
      - moodle
    environment:
      - POSTGRES_USER=postgres
      - POSTGRES_PASSWORD=postgres
    ports:
      - "5432:5432"
  moodle:
    restart: always
    networks:
      - moodle
    image: nerd4ver/moodle
    ports:
      - "8081:80"
    links:
      - db
    depends_on:
      - db
networks:
  moodle:
    driver: bridge
````

Veja um exemplo de uso no Kubernetes, para ilustrar esse exemplo o banco de dados foi instalado via helm em um cluster de alta disponibilidade em um chart feito pela bitnami, o arquivo **override-postgresql-values.yaml** deve ser seu próprio com suas customizações e as credênciais de acesso devem ser as mesmas que estão declaradas no config-map, além disso antes de iniciar o wordpress é necessário que o banco de dados já esteja criado e que o usuário tenha acesso a ele.

## Instalando o PostgreSQL com alta disponibilidade
Para informações detalhadas acesse o site da [bitnami](https://bitnami.com/stack/postgresql-ha/helm), essa instalação usa o helm.

````
helm install postgresql bitnami/postgresql-ha --values override-postgresql-values.yaml:
````

## Usando em kubernetes

Exemplo extraido do ambiente usado para homologar a imagem e testar

````
apiVersion: v1
kind: ConfigMap
metadata:
  name: my-config-map
data:
  uploads.ini: |
    file_uploads = On
    upload_max_filesize = 256M
    post_max_size = 256M
    memory_limit = 64M
    max_execution_time = 600
  POSTGRES_DB: postgres
  POSTGRES_USER: postgres
  POSTGRES_PASSWORD: postgres
  POSTGRES_CLUSTER: postgresql-postgresql-ha-pgpool
  POSTGRES_REPLICATION_MANAGER_PASSWORD: postgres
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: moodle-data-storage
spec:
  storageClassName: moodle-data-storage
  capacity:
    storage: 5Gi
  accessModes:
    - ReadWriteOnce
  hostPath:
    path: "/mnt/kubernetes/moodle-data/"
    type: DirectoryOrCreate
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: moodle-disk
  labels:
    app: moodle
spec:
  storageClassName: moodle-data-storage
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 5Gi
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: moodle
  labels:
    app: moodle
spec:
  replicas: 1
  selector:
    matchLabels:
      app: moodle
      tier: frontend
  strategy:
    type: Recreate
  template:
    metadata:
      labels:
        app: moodle
        tier: frontend
    spec:
      volumes:
      - name: moodle-volume
        persistentVolumeClaim:
          claimName: moodle-disk
      - name: php-config-volume
        configMap:
          name: my-config-map
      containers:
      - image: nerd4ever/moodle
        name: moodle
        env:
        - name: WORDPRESS_DB_HOST
          valueFrom:
            configMapKeyRef:
              name: my-config-map
              key: POSTGRES_CLUSTER
        - name: WORDPRESS_DB_USER
          valueFrom:
            configMapKeyRef:
              name: my-config-map
              key: POSTGRES_USER
        - name: WORDPRESS_DB_PASSWORD
          valueFrom:
            configMapKeyRef:
              name: my-config-map
              key: POSTGRES_PASSWORD
        - name: WORDPRESS_DB_NAME
          value: "moodle"
        resources:
          limits:
            cpu: 500m
            memory: 2Gi
          requests:
            cpu: 250m
            memory: 512Mi
        ports:
        - containerPort: 80
          name: moodle
        volumeMounts:
        - name: moodle-volume
          mountPath: /var/www/moodle
        - name: php-config-volume
          mountPath: /usr/local/etc/php/conf.d/uploads.ini
          subPath: uploads.ini
---
apiVersion: v1
kind: Service
metadata:
  name: moodle
  labels:
    app: moodle
spec:
  ports:
    - port: 80
      targetPort: 80
  selector:
    app: moodle
    tier: frontend
````