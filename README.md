# Automation Scripts Repository

This repository contains a collection of useful automation scripts for various tasks, such as deploying Docker images to AWS Elastic Container Registry (ECR), automating deployments, and more. The goal is to streamline various development and deployment workflows.

## Scripts

### 1. **Deploy Docker Image to AWS ECR**

This script automates the process of deploying a Docker image to AWS Elastic Container Registry (ECR). It handles all steps from starting Docker Desktop, logging in to AWS ECR, creating the repository (if it doesn't exist), building the Docker image, tagging it for ECR, and finally pushing the image to the repository.

#### How to Use

1. Ensure you have Docker Desktop on your machine and AWS CLI configured.
2. Clone this repository to your local machine.
3. Open your terminal and navigate to the directory where you saved the repository.
4. Run the following command:

    ```bash
    ./deploy.sh <image_name>
    ```

    Replace `<image_name>` with the name of the Docker image you wish to deploy.

#### Prerequisites

- Docker Desktop installed.
- AWS CLI installed and configured with appropriate credentials.
- An AWS ECR account and the necessary permissions to push to repositories.

#### Script Details

- **Checks if Docker Desktop is running**: If not, it will automatically start Docker Desktop.
- **Logs into AWS ECR**: Uses AWS CLI to authenticate the Docker client to ECR.
- **Checks if the repository exists**: If the repository doesn't exist, it will be created.
- **Builds the Docker image**: Uses the provided image name to build the Docker image.
- **Tags the image for ECR**: Tags the image with the ECR URI.
- **Pushes the image to ECR**: Uploads the tagged image to your AWS ECR repository.
- **Opens AWS Console**: Automatically opens the ECR repository page in your browser after the push.

#### Example Usage

```bash
./deploy.sh my-docker-image
```

This will deploy the my-docker-image Docker image to your AWS ECR repository.

## Future Scripts

As this repository evolves, additional automation scripts will be added for various tasks, including but not limited to:

- Continuous integration/deployment pipelines.
- Database backups and restoration automation.
- Monitoring and alerting scripts.
- Infrastructure as Code (IaC) automation scripts.
  
Each new script will be added with its own detailed instructions on how to use and configure it.

## Contributing

Feel free to fork this repository and contribute your own automation scripts! If you find any issues or would like to suggest improvements, please open an issue or submit a pull request.

## License

This project is licensed under the MIT License - see the LICENSE file for details.
