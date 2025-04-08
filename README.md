# CLITasker: AWS CLI-Based Full Stack Deployment

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
├── run.sh                        
└── README.md

Prerequisites

AWS CLI installed & configured (aws configure)

An IAM user/role with permissions to manage:

EC2, VPC, RDS, S3, IAM, Lambda, Secrets Manager, CloudWatch

A key pair already created in AWS (name: aws-cli-project-key)


Deployment

bash master-deploy.sh


How to Access

aws elbv2 describe-load-balancers \
  --names aws-cli-project-alb \
  --region eu-central-1 \
  --query 'LoadBalancers[0].DNSName' \
  --output text

Then visit:

/
/db
/upload
