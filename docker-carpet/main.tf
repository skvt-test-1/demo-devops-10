data "aws_ssm_parameter" "ubuntuAmi" {
  name = "/aws/service/canonical/ubuntu/server/24.04/stable/current/amd64/hvm/ebs-gp3/ami-id" # verify available version
}

resource "aws_instance" "ec2-model-train-server" {
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
  depends_on = [aws_instance.ec2-model-train-server]

  provisioner "remote-exec" {
    inline = [
      "echo 'Sleeping for 30 seconds...'",
      "sleep 30",  # Sleep for 30 seconds
      "echo 'Sleep completed!'"
    ]

    connection {
      type        = "ssh"
      host        = aws_instance.ec2-model-train-server.public_ip
      user        = "ubuntu"
      private_key = file("./bootcamp-peru-demo.pem") # enter file name
    }
  }
}

resource "null_resource" "install_docker" {
  depends_on = [aws_instance.ec2-model-train-server, null_resource.sleep_example]

  provisioner "remote-exec" {
    inline = [
        "sudo apt update",
        "sudo apt upgrade -y",
        "sudo apt install -y ca-certificates curl",
        "sudo install -m 0755 -d /etc/apt/keyrings",
        "sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc",
        "sudo chmod a+r /etc/apt/keyrings/docker.asc"
    ]

    connection {
      type        = "ssh"
      host        = aws_instance.ec2-model-train-server.public_ip
      user        = "ubuntu"
      private_key = file("./bootcamp-peru-demo.pem")
    }
  }

  provisioner "file" {
    source      = "./docker.sources"        # Local path of docker.sources
    destination = "/tmp/docker.sources"     # Destination path on the EC2 instance

    connection {
      type        = "ssh"
      host        = aws_instance.ec2-model-train-server.public_ip
      user        = "ubuntu"   # Ubuntu default user
      private_key = file("./bootcamp-peru-demo.pem")        # Path to your private key
    }
  }

  provisioner "remote-exec" {
    inline = [
      "sudo install -m 0644 /tmp/docker.sources /etc/apt/sources.list.d/docker.sources", 
      "echo 'Esperando a que APT libere los bloqueos...'",
      "while sudo fuser /var/lib/apt/lists/lock >/dev/null 2>&1 || sudo fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1; do echo 'APT ocupado. Esperando 5 segundos...'; sleep 5; done", 
      "sudo apt update",
      "sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin",
      "sudo usermod -aG docker ubuntu"
    ]

    connection {
      type        = "ssh"
      host        = aws_instance.ec2-model-train-server.public_ip
      user        = "ubuntu"
      private_key = file("./bootcamp-peru-demo.pem")
    }
  }
}
