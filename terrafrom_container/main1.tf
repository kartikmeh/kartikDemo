variable "aws_access_key_id" {}

variable "aws_secret_access_key" {}

variable "region" {
  description = "AWS region"
  default = "us-east-2"
}
# Setup our aws provider
provider "aws" {
  access_key  = "${var.aws_access_key_id}"
  secret_key  = "${var.aws_secret_access_key}"
  region      = "${var.region}"
}


data "aws_ecs_container_definition" "demo" {
  task_definition = "${aws_ecs_task_definition.demo.id}"
  container_name  = "demo"
}

data "aws_ecs_task_definition" "demo" {
    depends_on = [ "aws_ecs_task_definition.demo" ]
  task_definition = "${aws_ecs_task_definition.demo.family}"
}


resource "aws_ecs_task_definition" "demo" {
  family = "def"

  container_definitions = <<DEFINITION
[
  {
  
    "cpu": 12,
    "environment": [{
      "name": "SECRET",
      "value": "KEY"
    }],
    "essential": true,
    "image": "309244954780.dkr.ecr.us-east-2.amazonaws.com/docker-ecs:latest",
    "memory": 128,
    "memoryReservation": 64,
    "name": "demo",
     "portMappings": [
        {
          "hostPort": 8080,
          "protocol": "tcp",
          "containerPort": 8080
        }
    ]
  }
]
DEFINITION
}







resource "aws_ecs_cluster" "demo" {
  name = "demo15"
}


resource "aws_iam_role" "ecs_ingest" {
  name = "iam_role15"
  assume_role_policy = <<EOF
{
"Version": "2012-10-17",
"Statement": [
  {
    "Effect": "Allow",
    "Principal": {
      "Service": "ec2.amazonaws.com"
    },
    "Action": "sts:AssumeRole"
  }
]
}
EOF
}

resource "aws_iam_role_policy" "ecs_ingest" { 
  name = "iam_policy15"
  role = "${aws_iam_role.ecs_ingest.id}"
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ecs:CreateCluster",
        "ecs:DeregisterContainerInstance",
        "ecs:DiscoverPollEndpoint",
        "ecs:Poll",
        "ecs:RegisterContainerInstance",
        "ecs:StartTelemetrySession",
        "ecs:Submit*",
        "ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage",
        "ecs:StartTask"
      ],
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_iam_instance_profile" "ingest" {
  name = "iam_profile15"
  roles = ["${aws_iam_role.ecs_ingest.name}"]
}

resource "aws_instance" "demo" {
  # ECS-optimized AMI for us-east-1
  ami = "ami-956e52f0"
  vpc_security_group_ids =["sg-9899f4f2"]
  subnet_id   =  "subnet-6942bd24"
  instance_type = "t2.micro"
  key_name="kartik"
  user_data = <<EOF
#!/bin/bash
echo ECS_CLUSTER=${aws_ecs_cluster.demo.name} >> /etc/ecs/ecs.config
EOF
iam_instance_profile = "${aws_iam_instance_profile.ingest.name}"
tags {
    Name = "demo"
  }
}
resource "aws_ecs_service" "demo" {
  name          = "demo"
  cluster       = "demo15"
  desired_count = 1
  # Track the latest ACTIVE revision
  task_definition = "${aws_ecs_task_definition.demo.family}:${max("${aws_ecs_task_definition.demo.revision}", "${data.aws_ecs_task_definition.demo.revision}")}"
 
   placement_constraints {
    type       = "memberOf"
    expression = "attribute:ecs.availability-zone in [us-east-2c,us-east-2a, us-east-2b]"
  }
  
}




resource "aws_cloudwatch_dashboard" "main" {
   dashboard_name = "my-dashboard"
   dashboard_body = <<EOF
 {
   "widgets": [
       {
          "type":"metric",
          "x":0,
          "y":0,
          "width":12,
          "height":6,
          "properties":{
             "metrics":[
                [
                   "AWS/EC2",
                   "CPUUtilization",
                   "InstanceId",
                   "${aws_instance.demo.id}"
                ]
             ],
             "period":300,
             "stat":"Average",
             "region":"us-east-1",
             "title":"EC2 Instance CPU"
          }
       }
   ]
 }
 EOF
}


