// in prod.tf
locals {
    prod = {
        apps_instance_type = "t2.micro",
        desired_capacity = 2,
        target_value = 50.0,
        min_size = 2,
        max_size = 4,
        db_allocated_storage = 10,
        db_instance_class = "db.t2.micro",
        db_multi_az = true
    }
}