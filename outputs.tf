output "bastion_address" {
  value = "${openstack_compute_floatingip_v2.bastion.address}"
}
output "manager_address" {
  value = "${openstack_compute_floatingip_v2.manager.address}"
}
