#!/bin/bash

# Check if the user has provided an image name as a parameter
if [ -z "$1" ]; then
    echo "Error: You must specify the image name."
    echo "Usage: $0 <image_name>"
    exit 1
fi

# Check the operating system and save it in a variable
OS=$(uname -s)
if [[ "$OS" == "Linux" ]]; then
    echo "Operating system: Linux"
elif [[ "$OS" == "Darwin" ]]; then
    echo "Operating system: macOS"
elif [[ "$OS" == "Windows_NT" ]]; then
    echo "Operating system: Windows"
elif [[ "$OS" != "Linux" && "$OS" != "Darwin" && "$OS" != "Windows_NT" ]]; then
    echo "Error: Unsupported operating system ($OS). This script only works on Linux, macOS, and Windows."
    exit 1
fi

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo "AWS CLI is not installed. Install it by following the instructions at https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html"
    exit 1
fi

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo "Docker is not installed. Install it by following the instructions at https://docs.docker.com/get-docker/"
    exit 1
fi

# Check if the user is logged into AWS
if ! aws sts get-caller-identity &> /dev/null; then
    echo "You are not logged into AWS. Log in using 'aws configure'."
    exit 1
fi

# Retrieve the AWS account ID
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
if [ $? -ne 0 ]; then
    echo "Error retrieving the account ID. Make sure you are logged into AWS."
    exit 1
fi

# Image name and ECR repository
IMAGE_NAME=$1
ECR_REPOSITORY=$IMAGE_NAME 

# Ask the user to specify the AWS region if not already defined
if [ -z "$AWS_REGION" ]; then
    read -p "Enter the AWS region (default: eu-west-3): " USER_AWS_REGION
    AWS_REGION="${USER_AWS_REGION:-eu-west-3}" # Use the user-provided value or the default
fi

# Start Docker Desktop if it is not already running
if ! docker info > /dev/null 2>&1; then
    echo "Docker Desktop is not running. Starting Docker Desktop..."
    if [[ "$OS" == "Linux" ]]; then
        sudo systemctl start docker
    elif [[ "$OS" == "Darwin" ]]; then
        open -a Docker
    elif [[ "$OS" == "Windows_NT" ]]; then
        DOCKER_DESKTOP_PATH=$(reg query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\Docker Desktop.exe" /ve 2>nul | awk -F '    ' '{print $2}')
        if [ -z "$DOCKER_DESKTOP_PATH" ]; then
            echo "Error: Unable to find the path to Docker Desktop. Make sure it is installed correctly."
            exit 1
        fi
        start "" "$DOCKER_DESKTOP_PATH"
    fi
    MAX_WAIT=60  # Maximum timeout in seconds
    WAITED=0
    while ! docker info > /dev/null 2>&1; do
        echo "Waiting for Docker Desktop to start..."
        sleep 5
        WAITED=$((WAITED + 5))
        if [ $WAITED -ge $MAX_WAIT ]; then
            echo "Error: Docker Desktop did not start within the timeout period."
            exit 1
        fi
    done
else
    echo "Docker Desktop is already running."
fi

echo "Docker is running."

# Login to AWS ECR
echo "Logging into AWS ECR..."
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com
if [ $? -ne 0 ]; then
    echo "Error: Login to AWS ECR failed."
    exit 1
fi

# Create the repository if it does not exist
echo "Checking if repository exists..."
aws ecr describe-repositories --repository-names $ECR_REPOSITORY --region $AWS_REGION > /dev/null 2>&1
if [ $? -ne 0 ]; then
    echo "Repository not found. Creating..."
    aws ecr create-repository --repository-name $ECR_REPOSITORY --region $AWS_REGION
    if [ $? -ne 0 ]; then
        echo "Error: Repository creation failed."
        exit 1
    fi
fi

# Build the Docker image
echo "Building Docker image..."
docker build -t $IMAGE_NAME .
if [ $? -ne 0 ]; then
    echo "Error: Docker image build failed."
    exit 1
fi
echo "Docker image built successfully."

# Tag the image for ECR
ECR_IMAGE_URI="$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPOSITORY:latest"
echo "Tagging image..."
docker tag $IMAGE_NAME:latest $ECR_IMAGE_URI
if [ $? -ne 0 ]; then
    echo "Error: Image tagging failed."
    exit 1
fi
echo "Image tagged successfully."

# Push the image to ECR
echo "Pushing image to ECR..."
docker push $ECR_IMAGE_URI
if [ $? -ne 0 ]; then
    echo "Error: Image push to ECR failed."
    exit 1
fi
echo "Image pushed successfully."

echo "Done! Image pushed to $ECR_IMAGE_URI"

# Ask if the user wants to delete the local image
read -p "Do you want to delete the local image? (y/n): " DELETE_IMAGE
if [[ "$DELETE_IMAGE" == "y" || "$DELETE_IMAGE" == "Y" ]]; then
    echo "Deleting local image..."
    docker rmi $IMAGE_NAME:latest
    if [ $? -ne 0 ]; then
        echo "Error: Failed to delete the local image."
        exit 1
    fi
    echo "Local image deleted successfully."
else
    echo "Local image not deleted."
fi

# Open AWS console in the browser
echo "Opening AWS console..."
if [[ "$OS" == "Linux" ]]; then
    xdg-open "https://$AWS_REGION.console.aws.amazon.com/ecr/repositories/$ECR_REPOSITORY?region=$AWS_REGION"
elif [[ "$OS" == "Darwin" ]]; then
    open "https://$AWS_REGION.console.aws.amazon.com/ecr/repositories/$ECR_REPOSITORY?region=$AWS_REGION"
elif [[ "$OS" == "Windows_NT" ]]; then
    start "https://$AWS_REGION.console.aws.amazon.com/ecr/repositories/$ECR_REPOSITORY?region=$AWS_REGION"
fi
echo "AWS console opened."

# Automatic configuration of the 'deploy' alias
# ALIAS_NAME="deploy"  # Define the alias name as 'deploy'
# SCRIPT_PATH="$(realpath "$0")" # Get the absolute path of the script being executed

# Determine the shell configuration file based on the shell being used
# if [ -n "$ZSH_VERSION" ]; then
#     SHELL_CONFIG="$HOME/.zshrc"  # Use .zshrc for Zsh shell
# elif [ -n "$BASH_VERSION" ]; then
#     SHELL_CONFIG="$HOME/.bashrc"  # Use .bashrc for Bash shell
# fi

# Check if the alias already exists in the current shell
# if ! alias "$ALIAS_NAME" &> /dev/null; then
#     # Prompt the user to confirm if they want to create the alias
#     read -p "Do you want to create the alias '$ALIAS_NAME' for the command '$SCRIPT_PATH'? (y/n): " user_input
#     if [[ "$user_input" == "y" || "$user_input" == "Y" ]]; then
#         # Add the alias to the shell configuration file
#         echo "alias $ALIAS_NAME='$SCRIPT_PATH'" >> "$SHELL_CONFIG"
#         echo "Alias '$ALIAS_NAME' added successfully."
#         echo "To activate the alias, reload the shell or run 'source $SHELL_CONFIG'."
#     else
#         # Inform the user that the alias was not created
#         echo "Alias not created."
#     fi
# fi
