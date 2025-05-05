# CLITasker: AWS CLI-Based Full Stack Project

CLITasker is a complete, modular infrastructure + app deployment stack using **AWS CLI** and **shell scripting**

It provisions and deploys:
- A full VPC with public/private subnets
- EC2 instance bootstrapped with a simple Flask app
- RDS PostgreSQL instance with credentials in Secrets Manager
- ALB (Application Load Balancer) + target group + listener
- Private S3 bucket for file uploads
- Daily-triggered Lambda function that writes to S3
- CloudWatch alarms for EC2 and ALB health

---

## Project Structure

├── 01-create-vpc.sh              
├── 02-create-security-groups.sh  
├── 03-create-rds.sh              
├── 04-create-s3.sh               
├── 05-create-iam-roles.sh        
├── 06-launch-ec2.sh              
├── 07-setup-elb.sh               
├── 08-create-lambda.sh           
├── 09-cloudwatch-alarms.sh                      
├── master-deploy.sh                       
├── secret-manager.sh             
├── user-data.sh                  
├── app.py                        
├── upload.html                   
├── handler.py                    
├── requirements.txt                                     
└── README.md

## How to use

### Prerequisites

AWS CLI configured with your credentials (command aws configure)
Python 3.x installed
EC2 key pair available (modify scripts accordingly)
Proper IAM permissions to provision AWS services

You can deploy everything using 'bash master-deploy.sh'

### Learning goals

I built this project to better understand AWS resources provisioned via CLI
Also to learn about networking, compute, storage and IAM setup
Pratice modular automation and bootstrapping
Explore CloudWatch monitoring and Lambda scheduling
Also one of the main goals was to setup a base project that i can recreate using Terraform later and also implement a CI/CD pipelines inside of it


