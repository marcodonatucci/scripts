#!/bin/bash

# Verifica che l'utente abbia passato un nome per l'immagine come parametro
if [ -z "$1" ]; then
    echo "Errore: devi specificare il nome dell'immagine."
    echo "Uso: $0 <nome_immagine>"
    exit 1
fi

# Verifica il sistema operativo e lo salvo in una variabile
OS=$(uname -s)
if [[ "$OS" == "Linux" ]]; then
    echo "Sistema operativo: Linux"
elif [[ "$OS" == "Darwin" ]]; then
    echo "Sistema operativo: macOS"
elif [[ "$OS" == "Windows_NT" ]]; then
    echo "Sistema operativo: Windows"
elif [[ "$OS" != "Linux" && "$OS" != "Darwin" && "$OS" != "Windows_NT" ]]; then
    echo "Errore: sistema operativo non supportato ($OS). Questo script funziona solo su Linux, macOS e Windows."
    exit 1
fi

# Verifica che AWS CLI sia installato
if ! command -v aws &> /dev/null; then
    echo "AWS CLI non è installato. Installalo seguendo le istruzioni su https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html"
    exit 1
fi

# Verifica che Docker sia installato
if ! command -v docker &> /dev/null; then
    echo "Docker non è installato. Installalo seguendo le istruzioni su https://docs.docker.com/get-docker/"
    exit 1
fi

# Verifica che l'utente abbia effettuato il login ad AWS
if ! aws sts get-caller-identity &> /dev/null; then
    echo "Non sei loggato ad AWS. Effettua il login con 'aws configure'."
    exit 1
fi

# Recupero l'account ID dell'utente AWS
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
if [ $? -ne 0 ]; then
    echo "Errore nel recupero dell'account ID. Assicurati di essere loggato ad AWS."
    exit 1
fi

# Nome dell'immagine e repository ECR
IMAGE_NAME=$1
ECR_REPOSITORY=$IMAGE_NAME 

# Chiedo all'utente di specificare la regione AWS se non è già definita
if [ -z "$AWS_REGION" ]; then
    read -p "Inserisci la regione AWS (default: eu-west-3): " USER_AWS_REGION
    AWS_REGION="${USER_AWS_REGION:-eu-west-3}" # Usa il valore inserito dall'utente o il default
fi

# Apro docker desktop se non è già in esecuzione
if ! docker info > /dev/null 2>&1; then
    echo "Docker Desktop non è in esecuzione. Avvio Docker Desktop..."
    if [[ "$OS" == "Linux" ]]; then
        sudo systemctl start docker
    elif [[ "$OS" == "Darwin" ]]; then
        open -a Docker
    elif [[ "$OS" == "Windows_NT" ]]; then
        DOCKER_DESKTOP_PATH=$(reg query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\Docker Desktop.exe" /ve 2>nul | awk -F '    ' '{print $2}')
        if [ -z "$DOCKER_DESKTOP_PATH" ]; then
            echo "Errore: impossibile trovare il percorso di Docker Desktop. Assicurati che sia installato correttamente."
            exit 1
        fi
        start "" "$DOCKER_DESKTOP_PATH"
    fi
    MAX_WAIT=60  # Timeout massimo in secondi
    WAITED=0
    while ! docker info > /dev/null 2>&1; do
        echo "Aspettando che Docker Desktop si avvii..."
        sleep 5
        WAITED=$((WAITED + 5))
        if [ $WAITED -ge $MAX_WAIT ]; then
            echo "Errore: Docker Desktop non si è avviato entro il tempo limite."
            exit 1
        fi
    done
else
    echo "Docker Desktop è già in esecuzione."
fi

echo "Docker is running."

# Login a AWS ECR
echo "Logging into AWS ECR..."
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com
if [ $? -ne 0 ]; then
    echo "Errore: il login su AWS ECR è fallito."
    exit 1
fi

# Creazione del repository se non esiste
echo "Checking if repository exists..."
aws ecr describe-repositories --repository-names $ECR_REPOSITORY --region $AWS_REGION > /dev/null 2>&1
if [ $? -ne 0 ]; then
    echo "Repository not found. Creating..."
    aws ecr create-repository --repository-name $ECR_REPOSITORY --region $AWS_REGION
    if [ $? -ne 0 ]; then
        echo "Errore: la creazione del repository è fallita."
        exit 1
    fi
fi

# Build dell'immagine Docker
echo "Building Docker image..."
docker build -t $IMAGE_NAME .
if [ $? -ne 0 ]; then
    echo "Errore: il build dell'immagine Docker è fallito."
    exit 1
fi
echo "Docker image built successfully."

# Tag dell'immagine per ECR
ECR_IMAGE_URI="$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPOSITORY:latest"
echo "Tagging image..."
docker tag $IMAGE_NAME:latest $ECR_IMAGE_URI
if [ $? -ne 0 ]; then
    echo "Errore: il tagging dell'immagine è fallito."
    exit 1
fi
echo "Image tagged successfully."


# Push dell'immagine su ECR
echo "Pushing image to ECR..."
docker push $ECR_IMAGE_URI
if [ $? -ne 0 ]; then
    echo "Errore: il push dell'immagine su ECR è fallito."
    exit 1
fi
echo "Image pushed successfully."

echo "Done! Image pushed to $ECR_IMAGE_URI"

# Chiedo se si desidera eliminare l'immagine locale
read -p "Vuoi eliminare l'immagine locale? (y/n): " DELETE_IMAGE
if [[ "$DELETE_IMAGE" == "y" || "$DELETE_IMAGE" == "Y" ]]; then
    echo "Deleting local image..."
    docker rmi $IMAGE_NAME:latest
    if [ $? -ne 0 ]; then
        echo "Errore: l'eliminazione dell'immagine locale è fallita."
        exit 1
    fi
    echo "Local image deleted successfully."
else
    echo "Local image not deleted."
fi

# Apro AWS console nel browser
echo "Opening AWS console..."
if [[ "$OS" == "Linux" ]]; then
    xdg-open "https://$AWS_REGION.console.aws.amazon.com/ecr/repositories/$ECR_REPOSITORY?region=$AWS_REGION"
elif [[ "$OS" == "Darwin" ]]; then
    open "https://$AWS_REGION.console.aws.amazon.com/ecr/repositories/$ECR_REPOSITORY?region=$AWS_REGION"
elif [[ "$OS" == "Windows_NT" ]]; then
    start "https://$AWS_REGION.console.aws.amazon.com/ecr/repositories/$ECR_REPOSITORY?region=$AWS_REGION"
fi
echo "AWS console opened."
