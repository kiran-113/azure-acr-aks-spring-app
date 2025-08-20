# Spring Boot + MySQL on Kubernetes

This project runs a **Spring Boot application** with a **MySQL database** on Kubernetes.
It uses Docker for containerization and Kubernetes resources for deployment, storage, networking, and scaling.

---
## 📝 Prerequisites
```bash
Clone Repo:[text](https://github.com/kiran-113/azure-acr-aks-spring-app.git)

cd

```
---

## 🚀 Build & Push Docker Image

1. **Build the JAR inside your project (Spring Boot app):**

   ```bash
   mvn clean package -DskipTests
   ```

   This generates `target/app.jar`.


2. **Build the Docker image:**

    Note: Replace `kiran11113` with your docker hub name

   ```bash
   docker build -t kiran11113/spring-boot-mysql-app .
   ```

3. **Login to Docker Hub:**

   ```bash
   docker login
   ```

4. **Push the image:**

   Note: Replace `kiran11113` with your docker hub name

   ```bash
   docker push kiran11113/spring-boot-mysql-app
   ```

---

## 📦 Kubernetes Deployment

### 1. **MySQL (Database Layer)**

* **StatefulSet** → Runs MySQL with persistent identity.
* **PersistentVolume & PersistentVolumeClaim** → Stores MySQL data on disk, survives pod restarts.
* **Secret** → Stores root password securely (`MYSQL_ROOT_PASSWORD`).
* **ConfigMap** → Provides MySQL DB name and configs (`MYSQL_DATABASE=test`).
* **Service (ClusterIP)** → Internal access point (`mysql:3306`).

### 2. **Spring Boot Application (App Layer)**

* **Deployment** → Runs Spring Boot app pods.
* **Service (NodePort)** → Exposes app on `<NodeIP>:30090` → accessible as `http://localhost:30090` (or port-forward).

### 3. **Networking & Security**

* **NetworkPolicy** → Only allows the Spring Boot app pods to connect to MySQL. Blocks other pods.

### 4. **Scaling & Resilience**

* **HPA (HorizontalPodAutoscaler)** → Scales app pods (min 1 → max 5) based on CPU utilization.
* **RestartPolicy** → Ensures pods restart if they fail.

---
## Apply Resources
```bash
cd k8s_manifest
kubectl apply -f k8s.yaml (Should in PWD where k8s yaml)
```
---
## 🔍 Testing the Setup

### 1. **Check Application is Running**

```bash
Optional: To set default namespace: kubectl config set-context --current --namespace=spring-mysql

kubectl get pods -n spring-mysql

kubectl get svc -n spring-mysql

kubectl port-forward svc/application-svc 9090:9090 -n spring-mysql
```

Open app:

```
http://localhost:9090/
```

---

### 2. **Test DB Connectivity & NetworkPolicy**

✅ Allowed (from Spring Boot or MySQL client pod):

```bash
kubectl run mysql-client --rm -it --image=mysql:8.0 -n spring-mysql -- \
  mysql -h mysql -uroot -proot test
```
Once you see "mysql>' its connected properly

❌ Blocked (from a random pod):

```bash
kubectl run test-block --rm -it --image=busybox -n spring-mysql -- \
  telnet mysql 3306
```

This should fail if NetworkPolicy is working.

---

### 3. **Test Horizontal Pod Autoscaler (HPA)**

Check HPA:

```bash
kubectl get hpa -n spring-mysql
```

Generate load:

```bash
kubectl run -it --rm load-generator --image=busybox -n spring-mysql -- \
  sh -c "while true; do wget -q -O- http://application-svc:9090/fetch; done"
```

Observe scaling:

```bash
kubectl get pods -n spring-mysql -w
```

---

## ✅ Summary

* **Build & push image** → `docker build`, `docker push`
* **DB** → StatefulSet + PVC + Secret + ConfigMap + Service
* **App** → Deployment + NodePort Service
* **Security** → NetworkPolicy ensures only app ↔ DB allowed
* **Scaling** → HPA auto-scales Spring Boot pods under load

---
