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
- GitHub repository: `https://github.com/<your-username>/java-app-cicd.git`.

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
   - Push changes to `dev`, `stage`, or `prod` branches.
   - Jenkins will build, scan, and deploy the application via ArgoCD.

## Accessing the Application
- For `dev`, use the LoadBalancer URL (`kubectl get svc -n dev`).
- For `stage` and `prod`, configure DNS for Ingress hosts.# latest-java-cicd
