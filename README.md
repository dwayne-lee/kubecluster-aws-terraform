# kubecluster-aws-terraform
# Use Terraform and Ansible to spin up a 4-node Centos 7 Kubernetes cluster.

### Prepare your environment
1. Run `export AWS_PROFILE=key-pair-name`   # Initialize the profile you're using based upon your key-pair
2. Run `alias aws='aws --no-verify-ssl'`    # If terraform fails due to SSL restrictions on Corp networks
3. Run `ssh-add ~/.ssh/key-pair-name.pem`   # Add your private key (make sure your ssh key is in the target region)

If you don't know how to create and upload a key pair to aws, see here.
https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-key-pairs.html

### Edit variables:
1. cp template.terraform.tfvars terraform.tfvars
2. Edit terraform.tfvars adding your variable values accordingly

NOTE: Terraform will use ~/.aws/credentials so set them up using `aws configure`.

### Bootstrap terraform
1. Run `terraform init`
2. Run `terraform plan`
3. Run `terraform apply`

If your IP Address changes, and you lose access to ssh into your hosts, just run
`terraform apply` again and the security group will be updated with your new IP Address.

### To tear down all the created resources
1. Run `terraform destroy`


Refer to the README-Validate file for instructions on validating your cluster.

Please contact Dwayne Lee (dlee62@gmail.com) with any issues, suggestions.  Enjoy!

