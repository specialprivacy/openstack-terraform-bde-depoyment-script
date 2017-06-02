resource "openstack_images_image_v2" "debiantesting" {
  name   = "Debian Testing"
  image_source_url = "http://cdimage.debian.org/cdimage/openstack/testing/debian-testing-openstack-amd64.qcow2"
  container_format = "bare"
  disk_format = "qcow2"
}

resource "openstack_compute_keypair_v2" "terraform" {
  name       = "terraform"
  public_key = "${file("${var.ssh_key_file}.pub")}"
}

resource "openstack_networking_network_v2" "terraform" {
  name           = "terraform"
  admin_state_up = "true"
}

resource "openstack_networking_subnet_v2" "terraform" {
  name            = "terraform"
  network_id      = "${openstack_networking_network_v2.terraform.id}"
  # NOTE: 10.0.0.0/16 is used by Docker for its overlay networks
  cidr            = "10.1.0.0/16"
  ip_version      = 4
  dns_nameservers = ["8.8.8.8", "8.8.4.4"]
}

resource "openstack_networking_router_v2" "terraform" {
  name             = "terraform"
  admin_state_up   = "true"
  external_gateway = "${var.external_gateway}"
}

resource "openstack_networking_router_interface_v2" "terraform" {
  router_id = "${openstack_networking_router_v2.terraform.id}"
  subnet_id = "${openstack_networking_subnet_v2.terraform.id}"
}

resource "openstack_compute_secgroup_v2" "bastion" {
  name        = "bastion"
  description = "Bastion security group limited to SSH"

  rule {
    from_port   = 22
    to_port     = 22
    ip_protocol = "tcp"
    cidr        = "0.0.0.0/0"
  }

  rule {
    from_port   = -1
    to_port     = -1
    ip_protocol = "icmp"
    cidr        = "0.0.0.0/0"
  }
}

resource "openstack_compute_secgroup_v2" "consul" {
  name        = "consul"
  description = "Consul security group limited to Docker communication and consul"

  # ssh access reserved from bastion
  rule {
    from_port   = 22
    to_port     = 22
    ip_protocol = "tcp"
    cidr        = "${openstack_compute_instance_v2.bastion.access_ip_v4}/32"
  }

  # internal consul access
  rule {
    from_port   = 8500
    to_port     = 8500
    ip_protocol = "tcp"
    cidr        = "10.1.0.0/16"
  }

  rule {
    from_port   = -1
    to_port     = -1
    ip_protocol = "icmp"
    cidr        = "0.0.0.0/0"
  }
}

resource "openstack_compute_secgroup_v2" "manager" {
  name        = "manager"
  description = "Docker Manager security group limited to Docker communication"

  # ssh access reserved from bastion
  rule {
    from_port   = 22
    to_port     = 22
    ip_protocol = "tcp"
    cidr        = "${openstack_compute_instance_v2.bastion.access_ip_v4}/32"
  }

  # any possible application exposing on port 80
  rule {
    from_port   = 80
    to_port     = 80
    ip_protocol = "tcp"
    cidr        = "0.0.0.0/0"
  }

  # app-swarm-ui frontend access
  rule {
    from_port   = 88
    to_port     = 88
    ip_protocol = "tcp"
    cidr        = "0.0.0.0/0"
  }

  # internal docker access
  rule {
    from_port   = 2375
    to_port     = 2375
    ip_protocol = "tcp"
    cidr        = "10.1.0.0/16"
  }

  rule {
    from_port   = -1
    to_port     = -1
    ip_protocol = "icmp"
    cidr        = "0.0.0.0/0"
  }
}

resource "openstack_compute_secgroup_v2" "worker" {
  name        = "worker"
  description = "Docker Worker security group limited to Docker communication"

  # ssh access reserved from bastion
  rule {
    from_port   = 22
    to_port     = 22
    ip_protocol = "tcp"
    cidr        = "${openstack_compute_instance_v2.bastion.access_ip_v4}/32"
  }

  rule {
    from_port   = 1
    to_port     = 65535
    ip_protocol = "tcp"
    self        = true
  }

  rule {
    from_port   = 1
    to_port     = 65535
    ip_protocol = "udp"
    self        = true
  }

  rule {
    from_port   = -1
    to_port     = -1
    ip_protocol = "icmp"
    cidr        = "0.0.0.0/0"
  }
}

resource "openstack_compute_floatingip_v2" "bastion" {
  pool       = "${var.pool}"
  depends_on = ["openstack_networking_router_interface_v2.terraform"]
}

resource "openstack_compute_floatingip_associate_v2" "bastion" {
  floating_ip = "${openstack_compute_floatingip_v2.bastion.address}"
  instance_id = "${openstack_compute_instance_v2.bastion.id}"
}

resource "openstack_compute_instance_v2" "bastion" {
  name            = "bastion"
  image_name      = "${openstack_images_image_v2.debiantesting.name}"
  flavor_name     = "${var.bastion_flavor}"
  key_pair        = "${openstack_compute_keypair_v2.terraform.name}"
  security_groups = ["${openstack_compute_secgroup_v2.bastion.name}"]

  network {
    uuid = "${openstack_networking_network_v2.terraform.id}"
  }
}

resource "openstack_compute_instance_v2" "consul" {
  name            = "consul"
  image_name      = "${openstack_images_image_v2.debiantesting.name}"
  flavor_name     = "${var.consul_flavor}"
  key_pair        = "${openstack_compute_keypair_v2.terraform.name}"
  security_groups = ["${openstack_compute_secgroup_v2.consul.name}"]

  network {
    uuid = "${openstack_networking_network_v2.terraform.id}"
  }

  user_data = "${file("setup_consul.sh")}"
}

resource "openstack_compute_floatingip_v2" "manager" {
  pool       = "${var.pool}"
  depends_on = ["openstack_networking_router_interface_v2.terraform"]
}

resource "openstack_compute_floatingip_associate_v2" "manager" {
  floating_ip = "${openstack_compute_floatingip_v2.manager.address}"
  instance_id = "${openstack_compute_instance_v2.manager.id}"
}

data "template_file" "setup_manager" {
  template = "${file("setup_manager.sh.tpl")}"

  vars {
    consul_address = "${openstack_compute_instance_v2.consul.access_ip_v4}"
  }
}

resource "openstack_compute_instance_v2" "manager" {
  name            = "manager"
  image_name      = "${openstack_images_image_v2.debiantesting.name}"
  flavor_name     = "${var.docker_flavor}"
  key_pair        = "${openstack_compute_keypair_v2.terraform.name}"
  security_groups = ["${openstack_compute_secgroup_v2.manager.name}","${openstack_compute_secgroup_v2.worker.name}"]

  network {
    uuid = "${openstack_networking_network_v2.terraform.id}"
  }

  user_data = "${data.template_file.setup_manager.rendered}"
}

data "template_file" "setup_worker" {
  template = "${file("setup_worker.sh.tpl")}"

  vars {
    manager_address = "${openstack_compute_instance_v2.manager.access_ip_v4}"
    consul_address = "${openstack_compute_instance_v2.consul.access_ip_v4}"
  }
}

resource "openstack_compute_instance_v2" "worker" {
  name            = "worker"
  image_name      = "${openstack_images_image_v2.debiantesting.name}"
  flavor_name     = "${var.docker_flavor}"
  key_pair        = "${openstack_compute_keypair_v2.terraform.name}"
  security_groups = ["${openstack_compute_secgroup_v2.worker.name}"]

  network {
    uuid = "${openstack_networking_network_v2.terraform.id}"
  }

  user_data = "${data.template_file.setup_worker.rendered}"
}
