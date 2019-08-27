
provider "aws" {
  region = "${var.aws_region_name}"
}


### DEFINE AWS AMI (CentOS 7 Latest)
data "aws_ami" "centos7_ami_useast2" {
  most_recent       = true
  owners            = ["679593333241"]

  filter {
    name   = "name"
    values = ["CentOS Linux 7 x86_64 HVM EBS*"]
  }
}
# Call this using: "${data.aws_ami.centos7_ami_useast2.id}"


### DEFINE AWS SUBNETS
data "aws_subnet" "main_subnets" {
  count = "${length(var.subnet_ids)}"
  id = "${element(var.subnet_ids, count.index)}"
}


### KUBERNETES MASTER - Don't change the count....haven't tested with more than 1 master node.
resource "aws_instance" "kube-master" {
  count                    = "1"
  ami                        = "${data.aws_ami.centos7_ami_useast2.id}"
  instance_type = "t2.medium"
  associate_public_ip_address = "true"
  subnet_id = "${element(data.aws_subnet.main_subnets.*.id,count.index)}"
  vpc_security_group_ids = ["${aws_security_group.k8s_sg.id}"]
  key_name            = "${var.ssh_key_name}"
  tags {
    Name = "${format("kube-master%02d", count.index + 1)}"
  }
}


### KUBERNETES NODES - If you change the count here, adjust the Ansible inventory file section near the bottom.
resource "aws_instance" "kube-node" {
  count         = "3"
  ami           = "${data.aws_ami.centos7_ami_useast2.id}"
  instance_type = "t2.large"
  associate_public_ip_address = "true"
  subnet_id = "${element(data.aws_subnet.main_subnets.*.id,count.index)}"
  vpc_security_group_ids = ["${aws_security_group.k8s_sg.id}"]
  key_name      = "${var.ssh_key_name}"
  tags {
    Name = "${format("kube-node%02d", count.index + 1)}"
  }
}


### SECURITY GROUPS
resource "aws_security_group" "k8s_sg" {
  vpc_id = "vpc-e06f9b88"
}

resource "aws_security_group_rule" "allow_all_egress" {
  type            = "egress"
  from_port       = 0
  to_port         = 0
  protocol        = "all"
  cidr_blocks     = ["0.0.0.0/0"]
  description     = "Outbound access to ANY"
  security_group_id = "${aws_security_group.k8s_sg.id}"
}

resource "aws_security_group_rule" "allow_all_QL" {
  type            = "ingress"
  from_port       = 0
  to_port         = 0
  protocol        = "all"
  cidr_blocks     = ["12.165.188.0/24"]
  description     = "Management Ports for K8s Cluster"
  security_group_id = "${aws_security_group.k8s_sg.id}"
}

resource "aws_security_group_rule" "allow_all_myip" {
  type            = "ingress"
  from_port       = 0
  to_port         = 0
  protocol        = "all"
  cidr_blocks     = ["162.252.136.0/21"]
  description     = "Management Ports for K8s Cluster"
  security_group_id = "${aws_security_group.k8s_sg.id}"
}

resource "aws_security_group_rule" "allow_SG_any" {
  type            = "ingress"
  from_port       = 0
  to_port         = 0
  protocol        = "all"
  self            = true
  description     = "Any from SG for K8s Cluster"
  security_group_id = "${aws_security_group.k8s_sg.id}"
}


### OUTPUT ALL IP'S
output "master_ip" {
  value = "${aws_instance.kube-master.public_ip}"
}
output "worker_ips" {
  value = "${aws_instance.kube-node.*.public_ip}"
}


### Create the Ansible inventory file
resource "local_file" "inventory" {
  content  = "---"
  filename = "inventory"
  provisioner "local-exec" {
    command = <<EOD
cat <<EOF > inventory
[master]
kube-master ansible_host=${aws_instance.kube-master.public_ip}

[workers]
kube-node1 ansible_host=${aws_instance.kube-node.0.public_ip}
kube-node2 ansible_host=${aws_instance.kube-node.1.public_ip}
kube-node3 ansible_host=${aws_instance.kube-node.2.public_ip}

[all:vars]
ansible_ssh_common_args='-o StrictHostKeyChecking=no'
ansible_user=centos
ansible_ssh_private_key_file=~/.ssh/${var.ssh_key_name}
EOF
EOD
  }


### Run ansible playbook
  provisioner "local-exec" {
    command = "aws --no-verify-ssl ec2 wait instance-status-ok --region ${var.aws_region_name} --instance-ids ${aws_instance.kube-master.id} --profile ${var.aws_profile} && ansible-playbook -i inventory site.yml"
  }
}
