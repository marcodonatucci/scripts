#!/bin/bash

# Verifica che l'utente abbia passato un nome per l'immagine come parametro
if [ -z "$1" ]; then
    echo "Errore: devi specificare il nome dell'immagine."
    echo "Uso: $0 <nome_immagine>"
    exit 1
fi


# Nome dell'immagine e repository ECR
IMAGE_NAME=$1
AWS_ACCOUNT_ID=""
AWS_REGION=""
ECR_REPOSITORY="$IMAGE_NAME"  # Costruisce il nome del repository concatenando "topfly/"

# Open docker desktop and wait for it to be ready 
#check if docker desktop is running
if ! docker info > /dev/null 2>&1; then
    echo "Docker Desktop non è in esecuzione. Avvio Docker Desktop..."
    open -a Docker
    while ! docker info > /dev/null 2>&1; do
        echo "Aspettando che Docker Desktop si avvii..."
        sleep 5
    done
else
    echo "Docker Desktop è già in esecuzione."
fi

echo "Docker is running."

# Login a AWS ECR
echo "Logging into AWS ECR..."
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com

# Creazione del repository se non esiste
echo "Checking if repository exists..."
aws ecr describe-repositories --repository-names $ECR_REPOSITORY --region $AWS_REGION > /dev/null 2>&1
if [ $? -ne 0 ]; then
    echo "Repository not found. Creating..."
    aws ecr create-repository --repository-name $ECR_REPOSITORY --region $AWS_REGION
fi

# Build dell'immagine Docker
echo "Building Docker image..."
docker build -t $IMAGE_NAME .

# Tag dell'immagine per ECR
ECR_IMAGE_URI="$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPOSITORY:latest"
echo "Tagging image..."
docker tag $IMAGE_NAME:latest $ECR_IMAGE_URI

# Push dell'immagine su ECR
echo "Pushing image to ECR..."
docker push $ECR_IMAGE_URI

echo "Done! Image pushed to $ECR_IMAGE_URI"

# Open AWS console in the default web browser
echo "Opening AWS console..."
open "https://$AWS_REGION.console.aws.amazon.com/ecr/repositories/$ECR_REPOSITORY?region=$AWS_REGION"
echo "AWS console opened."
