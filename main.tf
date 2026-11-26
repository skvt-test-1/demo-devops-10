data "aws_ssm_parameter" "ubuntuAmi" {
  name = "/aws/service/canonical/ubuntu/server/24.04/stable/current/amd64/hvm/ebs-gp3/ami-id" # verify available version
}

resource "aws_instance" "ec2-ubuntu-datawarehouse" {
  ami                         = data.aws_ssm_parameter.ubuntuAmi.value
  instance_type               = "m7i-flex.large" # verify available type
  associate_public_ip_address = true
  vpc_security_group_ids      = ["sg-02e661e156fe2d005"]  # enter your security group
  subnet_id                   = "subnet-08ff37bffae6dbebd"  # enter your subnet
  key_name                    = "bootcamp-peru-demo" # enter only the name of the .pem file
  user_data = file("userdata.sh")

  root_block_device {
    volume_size = 30
    volume_type = "gp3"
  }

}

resource "null_resource" "sleep_example" {
  depends_on = [aws_instance.ec2-ubuntu-datawarehouse]

  provisioner "remote-exec" {
    inline = [
      "echo 'Sleeping for 30 seconds...'",
      "sleep 30",  # Sleep for 30 seconds
      "echo 'Sleep completed!'"
    ]

    connection {
      type        = "ssh"
      host        = aws_instance.ec2-ubuntu-datawarehouse.public_ip
      user        = "ubuntu"
      private_key = file("./bootcamp-peru-demo.pem") # enter file name
    }
  }
}

resource "null_resource" "before_create_virtual_environment" {
  depends_on = [aws_instance.ec2-ubuntu-datawarehouse, null_resource.sleep_example]

  provisioner "remote-exec" {
    inline = [
        "sudo apt upgrade -y",
        "sudo apt install python3-pip -y",
        "sudo apt install python3-venv -y",
        "mkdir my-project"
    ]

    connection {
      type        = "ssh"
      host        = aws_instance.ec2-ubuntu-datawarehouse.public_ip
      user        = "ubuntu"
      private_key = file("./bootcamp-peru-demo.pem")
    }
  }

}

resource "null_resource" "before_train" {
  depends_on = [aws_instance.ec2-ubuntu-datawarehouse, null_resource.sleep_example]

  provisioner "file" {
    source      = "./data"        # Local path of docker.sources
    destination = "/tmp/data"     # Destination path on the EC2 instance

    connection {
      type        = "ssh"
      host        = aws_instance.ec2-ubuntu-datawarehouse.public_ip
      user        = "ubuntu"           # Ubuntu default user
      private_key = file("./bootcamp-peru-demo.pem")        # Path to your private key
    }
  }

  provisioner "file" {
    source      = "./train_model.py"        # Local path of docker.sources
    destination = "/tmp/train_model.py"     # Destination path on the EC2 instance

    connection {
      type        = "ssh"
      host        = aws_instance.ec2-ubuntu-datawarehouse.public_ip
      user        = "ubuntu"           # Ubuntu default user
      private_key = file("./bootcamp-peru-demo.pem")        # Path to your private key
    }
  }

  provisioner "remote-exec" {
    inline = [
      "sudo mv /tmp/data my-project/data",
       "sudo mv /tmp/train_model.py my-project/train_model.py"
    ]

    connection {
      type        = "ssh"
      host        = aws_instance.ec2-ubuntu-datawarehouse.public_ip
      user        = "ubuntu"
      private_key = file("./bootcamp-peru-demo.pem")
    }
  }
}
