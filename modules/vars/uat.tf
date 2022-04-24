// in uat.tf
locals {
    uat = {
        apps_instance_type = "t2.micro",
        target_value = 70.0,
        min_size = 2,
        max_size = 4,
        db_allocated_storage = 10,
        db_instance_class = "db.t2.micro",
        db_multi_az = true
    }
}