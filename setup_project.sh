#!/bin/bash

# Create project directory structure
mkdir -p src/main/java/com/example/demo
mkdir -p src/main/resources
mkdir -p terraform/modules/vpc
mkdir -p terraform/modules/eks
mkdir -p terraform/modules/ecr
mkdir -p terraform/environments/dev
mkdir -p terraform/environments/stage
mkdir -p terraform/environments/prod
mkdir -p helm/templates
mkdir -p argocd

# Create root files
cat > .gitignore << EOL
# Ignore IDE files
.idea/
*.iml

# Ignore Maven build output
target/

# Ignore Terraform state files
*.tfstate
*.tfstate.backup
.terraform/

# Ignore Docker build artifacts
*.dockerignore

# Ignore temporary files
*.log
*.tmp

# Ignore sensitive files
*.env
*.secret
EOL

cat > Dockerfile << EOL
# Use OpenJDK 17 slim base image for smaller footprint
FROM openjdk:17-jdk-slim

# Set working directory inside the container
WORKDIR /app

# Copy the built JAR file from Maven
COPY target/demo-0.0.1-SNAPSHOT.jar app.jar

# Run the Spring Boot application
ENTRYPOINT ["java", "-jar", "app.jar"]
EOL

cat > Jenkinsfile << EOL
// Define the Jenkins pipeline
pipeline {
    agent any
    environment {
        AWS_REGION = 'us-east-1'
        ECR_REPOSITORY = credentials('ecr-repository-url')
        DOCKER_CREDENTIALS = 'docker-cred'
        GIT_CREDENTIALS = 'git-cred'
        SONAR_TOKEN = credentials('sonar-token')
        ARGOCD_SERVER = 'argocd.example.com'
        ARGOCD_CREDENTIALS = 'argocd-cred'
    }
    tools {
        maven 'maven3'
    }
    stages {
        stage('Checkout') {
            steps {
                git branch: env.BRANCH_NAME, credentialsId: env.GIT_CREDENTIALS, url: 'https://github.com/<your-username>/java-app-cicd.git'
            }
        }
        stage('Compile') {
            steps {
                sh 'mvn compile'
            }
        }
        stage('Unit Test') {
            steps {
                sh 'mvn test'
            }
        }
        stage('SonarQube Analysis') {
            steps {
                withSonarQubeEnv('sonar') {
                    sh """
                    mvn sonar:sonar \
                        -Dsonar.projectKey=java-app \
                        -Dsonar.host.url=http://sonarqube:9000 \
                        -Dsonar.login=\$SONAR_TOKEN
                    """
                }
            }
        }
        stage('Trivy Scan') {
            steps {
                sh 'trivy fs --format table -o trivy-report.html .'
            }
        }
        stage('Build Application') {
            steps {
                sh 'mvn package -DskipTests'
            }
        }
        stage('Docker Build') {
            steps {
                script {
                    docker.build("\${ECR_REPOSITORY}:\${env.BRANCH_NAME}-\${env.BUILD_NUMBER}")
                }
            }
        }
        stage('Push to ECR') {
            steps {
                script {
                    docker.withRegistry("https://\${ECR_REPOSITORY}", "ecr:\${AWS_REGION}:\${DOCKER_CREDENTIALS}") {
                        docker.image("\${ECR_REPOSITORY}:\${env.BRANCH_NAME}-\${env.BUILD_NUMBER}").push()
                        docker.image("\${ECR_REPOSITORY}:\${env.BRANCH_NAME}-\${env.BUILD_NUMBER}").push('latest')
                    }
                }
            }
        }
        stage('Update Helm Values') {
            when {
                anyOf {
                    branch 'dev'
                    branch 'stage'
                    branch 'prod'
                }
            }
            steps {
                sh """
                git checkout \${env.BRANCH_NAME}
                sed -i 's|tag:.*|tag: "\${env.BRANCH_NAME}-\${env.BUILD_NUMBER}"|' helm/values-\${env.BRANCH_NAME}.yaml
                git add helm/values-\${env.BRANCH_NAME}.yaml
                git commit -m "Update image tag for \${env.BRANCH_NAME} to \${env.BRANCH_NAME}-\${env.BUILD_NUMBER}"
                git push origin \${env.BRANCH_NAME}
                """
            }
        }
        stage('Deploy with ArgoCD') {
            when {
                anyOf {
                    branch 'dev'
                    branch 'stage'
                    branch 'prod'
                }
            }
            steps {
                withCredentials([usernamePassword(credentialsId: env.ARGOCD_CREDENTIALS, usernameVariable: 'ARGOCD_USER', passwordVariable: 'ARGOCD_PASS')]) {
                    sh """
                    argocd login \${ARGOCD_SERVER} --username \${ARGOCD_USER} --password \${ARGOCD_PASS} --insecure
                    argocd app sync java-app-\${env.BRANCH_NAME} --force
                    argocd app set java-app-\${env.BRANCH_NAME} --helm-set image.tag=\${env.BRANCH_NAME}-\${env.BUILD_NUMBER}
                    argocd app sync java-app-\${env.BRANCH_NAME} --force
                    """
                }
            }
        }
    }
    post {
        always {
            archiveArtifacts artifacts: 'trivy-report.html', allowEmptyArchive: true
        }
    }
}
EOL

cat > README.md << EOL
# Java App CI/CD with EKS, Helm, and ArgoCD

This project demonstrates a CI/CD pipeline for a Java Spring Boot application deployed to AWS EKS using Helm and ArgoCD.

## Project Structure
- `src/`: Java Spring Boot application source code.
- `terraform/`: Terraform configurations for AWS VPC, EKS, and ECR.
- `helm/`: Helm Chart for deploying the application.
- `argocd/`: ArgoCD application manifests for dev, stage, and prod.
- `Jenkinsfile`: Jenkins pipeline for CI/CD.
- `Dockerfile`: Docker configuration for the Java app.
- `pom.xml`: Maven configuration.

## Prerequisites
- AWS account with CLI configured.
- Terraform, Helm, Jenkins, and ArgoCD CLI installed.
- SonarQube and Trivy for code analysis and scanning.
- GitHub repository: \`https://github.com/<your-username>/java-app-cicd.git\`.

## Setup Instructions
1. **Clone the repository**:
   ```bash
   git clone https://github.com/<your-username>/java-app-cicd.git
   cd java-app-cicd
   ```

2. **Create environment branches**:
   ```bash
   git checkout -b dev
   git push origin dev
   git checkout -b stage
   git push origin stage
   git checkout -b prod
   git push origin prod
   ```

3. **Apply Terraform**:
   ```bash
   cd terraform
   terraform init
   terraform apply -var-file="environments/dev/variables.tfvars"
   ```

4. **Set up Jenkins**:
   - Install plugins: Docker, Docker Pipeline, SonarQube Scanner, Git, AWS Credentials.
   - Configure credentials for GitHub, ECR, SonarQube, and ArgoCD.
   - Set up a multibranch pipeline pointing to the repository.

5. **Install ArgoCD**:
   ```bash
   kubectl create namespace argocd
   kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
   ```

6. **Apply ArgoCD applications**:
   ```bash
   kubectl apply -f argocd/app-dev.yaml
   kubectl apply -f argocd/app-stage.yaml
   kubectl apply -f argocd/app-prod.yaml
   ```

7. **Trigger the pipeline**:
   - Push changes to \`dev\`, \`stage\`, or \`prod\` branches.
   - Jenkins will build, scan, and deploy the application via ArgoCD.

## Accessing the Application
- For \`dev\`, use the LoadBalancer URL (\`kubectl get svc -n dev\`).
- For \`stage\` and \`prod\`, configure DNS for Ingress hosts.
EOL

cat > pom.xml << EOL
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 http://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>
    <groupId>com.example</groupId>
    <artifactId>demo</artifactId>
    <version>0.0.1-SNAPSHOT</version>
    <packaging>jar</packaging>
    <parent>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-parent</artifactId>
        <version>3.2.5</version>
        <relativePath/>
    </parent>
    <dependencies>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-web</artifactId>
        </dependency>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-test</artifactId>
            <scope>test</scope>
        </dependency>
    </dependencies>
    <build>
        <plugins>
            <plugin>
                <groupId>org.springframework.boot</groupId>
                <artifactId>spring-boot-maven-plugin</artifactId>
            </plugin>
        </plugins>
    </build>
</project>
EOL

# Create source code files
cat > src/main/java/com/example/demo/DemoApplication.java << EOL
package com.example.demo;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

@SpringBootApplication
@RestController
public class DemoApplication {

    public static void main(String[] args) {
        SpringApplication.run(DemoApplication.class, args);
    }

    @GetMapping("/hello")
    public String hello() {
        return "Hello from Spring Boot!";
    }
}
EOL

cat > src/main/resources/application.properties << EOL
# Spring Boot configuration (empty for basic app)
EOL

# Create Terraform files
cat > terraform/main.tf << EOL
provider "aws" {
  region = var.aws_region
}

module "dev" {
  source = "./environments/dev"
}

module "stage" {
  source = "./environments/stage"
}

module "prod" {
  source = "./environments/prod"
}
EOL

cat > terraform/variables.tf << EOL
variable "aws_region" {
  description = "AWS region for resource deployment"
  type = string
  default = "us-east-1"
}
EOL

cat > terraform/outputs.tf << EOL
output "dev_eks_cluster_name" {
  value = module.dev.eks_cluster_name
}

output "dev_ecr_repository_url" {
  value = module.dev.ecr_repository_url
}

output "stage_eks_cluster_name" {
  value = module.stage.eks_cluster_name
}

output "stage_ecr_repository_url" {
  value = module.stage.ecr_repository_url
}

output "prod_eks_cluster_name" {
  value = module.prod.eks_cluster_name
}

output "prod_ecr_repository_url" {
  value = module.prod.ecr_repository_url
}
EOL

cat > terraform/modules/vpc/main.tf << EOL
resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr
  enable_dns_support = true
  enable_dns_hostnames = true
  tags = {
    Name = "\${var.env}-vpc"
  }
}

resource "aws_subnet" "public" {
  count = length(var.public_subnet_cidrs)
  vpc_id = aws_vpc.main.id
  cidr_block = var.public_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]
  map_public_ip_on_launch = true
  tags = {
    Name = "\${var.env}-public-subnet-\${count.index}"
    "kubernetes.io/role/elb" = "1"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "\${var.env}-igw"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
  tags = {
    Name = "\${var.env}-public-rt"
  }
}

resource "aws_route_table_association" "public" {
  count = length(var.public_subnet_cidrs)
  subnet_id = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}
EOL

cat > terraform/modules/vpc/variables.tf << EOL
variable "env" {
  type = string
}

variable "vpc_cidr" {
  type = string
}

variable "public_subnet_cidrs" {
  type = list(string)
}

variable "availability_zones" {
  type = list(string)
}
EOL

cat > terraform/modules/vpc/outputs.tf << EOL
output "vpc_id" {
  value = aws_vpc.main.id
}

output "public_subnet_ids" {
  value = aws_subnet.public[*].id
}
EOL

cat > terraform/modules/eks/main.tf << EOL
resource "aws_eks_cluster" "main" {
  name = "\${var.env}-eks-cluster"
  role_arn = aws_iam_role.eks.arn
  vpc_config {
    subnet_ids = var.subnet_ids
    security_group_ids = [aws_security_group.eks.id]
  }
  depends_on = [aws_iam_role_policy_attachment.eks]
}

resource "aws_eks_node_group" "main" {
  cluster_name = aws_eks_cluster.main.name
  node_group_name = "\${var.env}-node-group"
  node_role_arn = aws_iam_role.node.arn
  subnet_ids = var.subnet_ids
  scaling_config {
    desired_size = var.node_count
    max_size = var.node_count + 2
    min_size = var.node_count
  }
  instance_types = ["t3.medium"]
  depends_on = [aws_iam_role_policy_attachment.node]
}

resource "aws_iam_role" "eks" {
  name = "\${var.env}-eks-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "eks.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "eks" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role = aws_iam_role.eks.name
}

resource "aws_iam_role" "node" {
  name = "\${var.env}-eks-node-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "node" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role = aws_iam_role.node.name
}

resource "aws_security_group" "eks" {
  vpc_id = var.vpc_id
  name = "\${var.env}-eks-sg"
  ingress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "\${var.env}-eks-sg"
  }
}
EOL

cat > terraform/modules/eks/variables.tf << EOL
variable "env" {
  type = string
}

variable "subnet_ids" {
  type = list(string)
}

variable "vpc_id" {
  type = string
}

variable "node_count" {
  type = number
}
EOL

cat > terraform/modules/eks/outputs.tf << EOL
output "eks_cluster_name" {
  value = aws_eks_cluster.main.name
}
EOL

cat > terraform/modules/ecr/main.tf << EOL
resource "aws_ecr_repository" "main" {
  name = "\${var.env}-java-app"
  image_tag_mutability = "MUTABLE"
  image_scanning_configuration {
    scan_on_push = true
  }
  tags = {
    Name = "\${var.env}-java-app-ecr"
  }
}
EOL

cat > terraform/modules/ecr/variables.tf << EOL
variable "env" {
  type = string
}
EOL

cat > terraform/modules/ecr/outputs.tf << EOL
output "ecr_repository_url" {
  value = aws_ecr_repository.main.repository_url
}
EOL

cat > terraform/environments/dev/main.tf << EOL
module "vpc" {
  source = "../../modules/vpc"
  env = "dev"
  vpc_cidr = "10.0.0.0/16"
  public_subnet_cidrs = ["10.0.1.0/24", "10.0.2.0/24"]
  availability_zones = ["us-east-1a", "us-east-1b"]
}

module "eks" {
  source = "../../modules/eks"
  env = "dev"
  subnet_ids = module.vpc.public_subnet_ids
  vpc_id = module.vpc.vpc_id
  node_count = 2
}

module "ecr" {
  source = "../../modules/ecr"
  env = "dev"
}

output "eks_cluster_name" {
  value = module.eks.eks_cluster_name
}

output "ecr_repository_url" {
  value = module.ecr.ecr_repository_url
}
EOL

cat > terraform/environments/dev/variables.tfvars << EOL
aws_region = "us-east-1"
EOL

cat > terraform/environments/stage/main.tf << EOL
module "vpc" {
  source = "../../modules/vpc"
  env = "stage"
  vpc_cidr = "10.1.0.0/16"
  public_subnet_cidrs = ["10.1.1.0/24", "10.1.2.0/24"]
  availability_zones = ["us-east-1a", "us-east-1b"]
}

module "eks" {
  source = "../../modules/eks"
  env = "stage"
  subnet_ids = module.vpc.public_subnet_ids
  vpc_id = module.vpc.vpc_id
  node_count = 3
}

module "ecr" {
  source = "../../modules/ecr"
  env = "stage"
}

output "eks_cluster_name" {
  value = module.eks.eks_cluster_name
}

output "ecr_repository_url" {
  value = module.ecr.ecr_repository_url
}
EOL

cat > terraform/environments/stage/variables.tfvars << EOL
aws_region = "us-east-1"
EOL

cat > terraform/environments/prod/main.tf << EOL
module "vpc" {
  source = "../../modules/vpc"
  env = "prod"
  vpc_cidr = "10.2.0.0/16"
  public_subnet_cidrs = ["10.2.1.0/24", "10.2.2.0/24"]
  availability_zones = ["us-east-1a", "us-east-1b"]
}

module "eks" {
  source = "../../modules/eks"
  env = "prod"
  subnet_ids = module.vpc.public_subnet_ids
  vpc_id = module.vpc.vpc_id
  node_count = 4
}

module "ecr" {
  source = "../../modules/ecr"
  env = "prod"
}

output "eks_cluster_name" {
  value = module.eks.eks_cluster_name
}

output "ecr_repository_url" {
  value = module.ecr.ecr_repository_url
}
EOL

cat > terraform/environments/prod/variables.tfvars << EOL
aws_region = "us-east-1"
EOL

# Create Helm files
cat > helm/Chart.yaml << EOL
apiVersion: v2
name: java-app
description: A Helm chart for deploying a Java Spring Boot application
version: 0.1.0
appVersion: "0.0.1"
EOL

cat > helm/values.yaml << EOL
replicaCount: 1
image:
  repository: "<ecr-repository-url>"
  tag: "latest"
  pullPolicy: IfNotPresent
service:
  type: ClusterIP
  port: 80
ingress:
  enabled: false
resources:
  limits:
    cpu: "500m"
    memory: "512Mi"
  requests:
    cpu: "200m"
    memory: "256Mi"
EOL

cat > helm/values-dev.yaml << EOL
replicaCount: 1
image:
  repository: "<ecr-repository-url>"
  tag: "dev-\${BUILD_NUMBER}"
  pullPolicy: IfNotPresent
service:
  type: LoadBalancer
  port: 80
ingress:
  enabled: true
  hosts:
    - host: dev.java-app.local
      paths:
        - path: /
          pathType: Prefix
resources:
  limits:
    cpu: "300m"
    memory: "384Mi"
  requests:
    cpu: "100m"
    memory: "128Mi"
EOL

cat > helm/values-stage.yaml << EOL
replicaCount: 2
image:
  repository: "<ecr-repository-url>"
  tag: "stage-\${BUILD_NUMBER}"
  pullPolicy: IfNotPresent
service:
  type: ClusterIP
  port: 80
ingress:
  enabled: true
  hosts:
    - host: stage.java-app.local
      paths:
        - path: /
          pathType: Prefix
resources:
  limits:
    cpu: "400m"
    memory: "512Mi"
  requests:
    cpu: "200m"
    memory: "256Mi"
EOL

cat > helm/values-prod.yaml << EOL
replicaCount: 3
image:
  repository: "<ecr-repository-url>"
  tag: "prod-\${BUILD_NUMBER}"
  pullPolicy: IfNotPresent
service:
  type: ClusterIP
  port: 80
ingress:
  enabled: true
  hosts:
    - host: prod.java-app.local
      paths:
        - path: /
          pathType: Prefix
resources:
  limits:
    cpu: "500m"
    memory: "768Mi"
  requests:
    cpu: "300m"
    memory: "512Mi"
EOL

cat > helm/templates/deployment.yaml << EOL
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ .Release.Name }}-java-app
  namespace: {{ .Release.Namespace }}
spec:
  replicas: {{ .Values.replicaCount }}
  selector:
    matchLabels:
      app: {{ .Release.Name }}-java-app
  template:
    metadata:
      labels:
        app: {{ .Release.Name }}-java-app
    spec:
      containers:
        - name: java-app
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
          imagePullPolicy: {{ .Values.image.pullPolicy }}
          ports:
            - containerPort: 8080
          resources:
            {{ toYaml .Values.resources | nindent 12 }}
EOL

cat > helm/templates/service.yaml << EOL
apiVersion: v1
kind: Service
metadata:
  name: {{ .Release.Name }}-java-app
  namespace: {{ .Release.Namespace }}
spec:
  type: {{ .Values.service.type }}
  ports:
    - port: {{ .Values.service.port }}
      targetPort: 8080
      protocol: TCP
  selector:
    app: {{ .Release.Name }}-java-app
EOL

cat > helm/templates/ingress.yaml << EOL
{{- if .Values.ingress.enabled }}
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: {{ .Release.Name }}-java-app
  namespace: {{ .Release.Namespace }}
spec:
  rules:
  {{- range .Values.ingress.hosts }}
    - host: {{ .host }}
      http:
        paths:
        {{- range .paths }}
          - path: {{ .path }}
            pathType: {{ .pathType }}
            backend:
              service:
                name: {{ $.Release.Name }}-java-app
                port:
                  number: {{ $.Values.service.port }}
        {{- end }}
  {{- end }}
{{- end }}
EOL

# Create ArgoCD files
cat > argocd/app-dev.yaml << EOL
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: java-app-dev
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/<your-username>/java-app-cicd.git
    targetRevision: dev
    path: helm
    helm:
      valueFiles:
        - values-dev.yaml
  destination:
    server: https://kubernetes.default.svc
    namespace: dev
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
EOL

cat > argocd/app-stage.yaml << EOL
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: java-app-stage
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/<your-username>/java-app-cicd.git
    targetRevision: stage
    path: helm
    helm:
      valueFiles:
        - values-stage.yaml
  destination:
    server: https://kubernetes.default.svc
    namespace: stage
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
EOL

cat > argocd/app-prod.yaml << EOL
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: java-app-prod
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/<your-username>/java-app-cicd.git
    targetRevision: prod
    path: helm
    helm:
      valueFiles:
        - values-prod.yaml
  destination:
    server: https://kubernetes.default.svc
    namespace: prod
  sync多彩多姿的同步政策:
    automated:
      prune: true