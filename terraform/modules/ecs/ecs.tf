resource "aws_ecs_cluster" "ecs_cluster" {
    name                                = var.ecs_cluster_name
}

resource "aws_ecs_task_definition" "kong-service-task-definition" {
    family                              = "test-family"
    # container definitions describes the configurations for the task
    container_definitions               = jsonencode(
    [
    {
        "name"                          : "${var.kong_service_name}",
        "image"                         : "${var.kong_image_url}:${var.kong_image_tag}",
        "entryPoint"                    : []
        "essential"                     : true,
        "networkMode"                   : "awsvpc",
        "portMappings"                  : [
                                            {
                                                "containerPort" : var.kong_service_container_port,
                                                "hostPort"      : var.kong_service_container_port,
                                            }
                                          ]
        "healthCheck"                   : {
                                            "command"     : ["CMD", "kong", "health"],
                                            "interval"    : 5,
                                            "timeout"     : 5,
                                            "retries"     :3
                                          }
    }
    ] 
    )
    requires_compatibilities            = ["FARGATE"]
    network_mode                        = "awsvpc"
    cpu                                 = "256"
    memory                              = "512"
    execution_role_arn                  = aws_iam_role.ecsTaskExecutionRole.arn
    task_role_arn                       = aws_iam_role.ecsTaskRole.arn
}

resource "aws_ecs_service" "kong_ecs_service" {
    name                                = "${var.kong_service_name}"
    cluster                             = aws_ecs_cluster.ecs_cluster.arn
    task_definition                     = aws_ecs_task_definition.kong-service-task-definition.arn
    launch_type                         = "FARGATE"
    scheduling_strategy                 = "REPLICA"
    desired_count                       = var.kong_service_instance_count # the number of tasks you wish to run

  network_configuration {
    subnets                             = [aws_subnet.private_subnet_1.id , aws_subnet.private_subnet_2.id]
    assign_public_ip                    = false
    security_groups                     = [aws_security_group.ecs_sg.id, aws_security_group.alb_sg.id]
  }

# This block registers the tasks to a target group of the loadbalancer.
  load_balancer {
    target_group_arn                    = aws_lb_target_group.target_group.arn #the target group defined in the alb file
    container_name                      = "${var.kong_service_name}"
    container_port                      = var.kong_service_container_port
  }
  depends_on                            = [aws_lb_listener.listener]
}


resource "aws_ecs_task_definition" "auth-service-task-definition" {
    family                              = "test-family"
    # container definitions describes the configurations for the task
    container_definitions               = jsonencode(
    [
    {
        "name"                          : "${var.auth_service_name}",
        "image"                         : "${var.auth_image_url}:${var.auth_image_tag}",
        "entryPoint"                    : []
        "essential"                     : true,
        "networkMode"                   : "awsvpc",
        "portMappings"                  : [
                                            {
                                                "containerPort" : var.auth_service_container_port,
                                                "hostPort"      : var.auth_service_container_port,
                                            }
                                          ]
        "healthCheck"                   : {
                                            "command"     : ["CMD", "wget", "--no-verbose", "--tries=1", "--spider", "http://localhost:9999/health"],
                                            "interval"    : 5,
                                            "timeout"     : 5,
                                            "retries"     :3
                                          }
    }
    ] 
    )
    requires_compatibilities            = ["FARGATE"]
    network_mode                        = "awsvpc"
    cpu                                 = "256"
    memory                              = "512"
    execution_role_arn                  = aws_iam_role.ecsTaskExecutionRole.arn
    task_role_arn                       = aws_iam_role.ecsTaskRole.arn
}

resource "aws_ecs_service" "auth_ecs_service" {
    name                                = "${var.auth_service_name}"
    cluster                             = aws_ecs_cluster.ecs_cluster.arn
    task_definition                     = aws_ecs_task_definition.auth-service-task-definition.arn
    launch_type                         = "FARGATE"
    scheduling_strategy                 = "REPLICA"
    desired_count                       = var.auth_service_instance_count # the number of tasks you wish to run

  network_configuration {
    subnets                             = [aws_subnet.private_subnet_1.id , aws_subnet.private_subnet_2.id]
    assign_public_ip                    = false
    security_groups                     = [aws_security_group.ecs_sg.id, aws_security_group.alb_sg.id]
  }

# This block registers the tasks to a target group of the loadbalancer.
  load_balancer {
    target_group_arn                    = aws_lb_target_group.target_group.arn #the target group defined in the alb file
    container_name                      = "${var.auth_service_name}"
    container_port                      = var.auth_service_container_port
  }
  depends_on                            = [aws_lb_listener.listener]
}

resource "aws_ecs_task_definition" "rest-service-task-definition" {
    family                              = "test-family"
    # container definitions describes the configurations for the task
    container_definitions               = jsonencode(
    [
    {
        "name"                          : "${var.rest_service_name}",
        "image"                         : "${var.rest_image_url}:${var.rest_image_tag}",
        "essential"                     : true,
        "networkMode"                   : "awsvpc",
        "portMappings"                  : [
                                            {
                                                "containerPort" : var.rest_service_container_port,
                                                "hostPort"      : var.rest_service_container_port,
                                            }
                                          ]
    }
    ] 
    )
    requires_compatibilities            = ["FARGATE"]
    network_mode                        = "awsvpc"
    cpu                                 = "256"
    memory                              = "512"
    execution_role_arn                  = aws_iam_role.ecsTaskExecutionRole.arn
    task_role_arn                       = aws_iam_role.ecsTaskRole.arn
}

resource "aws_ecs_service" "rest_ecs_service" {
    name                                = "${var.rest_service_name}"
    cluster                             = aws_ecs_cluster.ecs_cluster.arn
    task_definition                     = aws_ecs_task_definition.rest-service-task-definition.arn
    launch_type                         = "FARGATE"
    scheduling_strategy                 = "REPLICA"
    desired_count                       = var.rest_service_instance_count # the number of tasks you wish to run

  network_configuration {
    subnets                             = [aws_subnet.private_subnet_1.id , aws_subnet.private_subnet_2.id]
    assign_public_ip                    = false
    security_groups                     = [aws_security_group.ecs_sg.id, aws_security_group.alb_sg.id]
  }

# This block registers the tasks to a target group of the loadbalancer.
  load_balancer {
    target_group_arn                    = aws_lb_target_group.target_group.arn #the target group defined in the alb file
    container_name                      = "${var.rest_service_name}"
    container_port                      = var.rest_service_container_port
  }
  depends_on                            = [aws_lb_listener.listener]
}

resource "aws_ecs_task_definition" "realtime-service-task-definition" {
    family                              = "test-family"
    # container definitions describes the configurations for the task
    container_definitions               = jsonencode(
    [
    {
        "name"                          : "${var.realtime_service_name}",
        "image"                         : "${var.realtime_image_url}:${var.realtime_image_tag}",
        "entryPoint"                    : ["/usr/bin/tini", "-s", "-g", "--"], // ignore /app/limits.sh
        "command"                       : ["sh", "-c", "/app/bin/migrate && /app/bin/realtime eval \"Realtime.Release.seeds(Realtime.Repo)\" && /app/bin/server"],
        "essential"                     : true,
        "networkMode"                   : "awsvpc",
        "portMappings"                  : [
                                            {
                                                "containerPort" : var.realtime_service_container_port,
                                                "hostPort"      : var.realtime_service_container_port,
                                            }
                                          ]
    }
    ] 
    )
    requires_compatibilities            = ["FARGATE"]
    network_mode                        = "awsvpc"
    cpu                                 = "256"
    memory                              = "512"
    execution_role_arn                  = aws_iam_role.ecsTaskExecutionRole.arn
    task_role_arn                       = aws_iam_role.ecsTaskRole.arn
}

resource "aws_ecs_service" "realtime_ecs_service" {
    name                                = "${var.realtime_service_name}"
    cluster                             = aws_ecs_cluster.ecs_cluster.arn
    task_definition                     = aws_ecs_task_definition.realtime-service-task-definition.arn
    launch_type                         = "FARGATE"
    scheduling_strategy                 = "REPLICA"
    desired_count                       = var.realtime_service_instance_count # the number of tasks you wish to run

  network_configuration {
    subnets                             = [aws_subnet.private_subnet_1.id , aws_subnet.private_subnet_2.id]
    assign_public_ip                    = false
    security_groups                     = [aws_security_group.ecs_sg.id, aws_security_group.alb_sg.id]
  }

# This block registers the tasks to a target group of the loadbalancer.
  load_balancer {
    target_group_arn                    = aws_lb_target_group.target_group.arn #the target group defined in the alb file
    container_name                      = "${var.realtime_service_name}"
    container_port                      = var.realtime_service_container_port
  }
  depends_on                            = [aws_lb_listener.listener]
}

resource "aws_ecs_task_definition" "imgproxy-service-task-definition" {
    family                              = "test-family"
    # container definitions describes the configurations for the task
    container_definitions               = jsonencode(
    [
    {
        "name"                          : "${var.imgproxy_service_name}",
        "image"                         : "${var.imgproxy_image_url}:${var.imgproxy_image_tag}",
        "entryPoint"                    : ["/usr/bin/tini", "-s", "-g", "--"], // ignore /app/limits.sh
        "command"                       : ["CMD", "imgproxy", "health"],
        "essential"                     : true,
        "networkMode"                   : "awsvpc",
        "portMappings"                  : [
                                            {
                                                "containerPort" : var.imgproxy_service_container_port,
                                                "hostPort"      : var.imgproxy_service_container_port,
                                            }
                                          ]
    }
    ] 
    )
    requires_compatibilities            = ["FARGATE"]
    network_mode                        = "awsvpc"
    cpu                                 = "256"
    memory                              = "512"
    execution_role_arn                  = aws_iam_role.ecsTaskExecutionRole.arn
    task_role_arn                       = aws_iam_role.ecsTaskRole.arn
}

resource "aws_ecs_service" "imgproxy_ecs_service" {
    name                                = "${var.imgproxy_service_name}"
    cluster                             = aws_ecs_cluster.ecs_cluster.arn
    task_definition                     = aws_ecs_task_definition.imgproxy-service-task-definition.arn
    launch_type                         = "FARGATE"
    scheduling_strategy                 = "REPLICA"
    desired_count                       = var.imgproxy_service_instance_count # the number of tasks you wish to run

  network_configuration {
    subnets                             = [aws_subnet.private_subnet_1.id , aws_subnet.private_subnet_2.id]
    assign_public_ip                    = false
    security_groups                     = [aws_security_group.ecs_sg.id, aws_security_group.alb_sg.id]
  }

# This block registers the tasks to a target group of the loadbalancer.
  load_balancer {
    target_group_arn                    = aws_lb_target_group.target_group.arn #the target group defined in the alb file
    container_name                      = "${var.imgproxy_service_name}"
    container_port                      = var.imgproxy_service_container_port
  }
  depends_on                            = [aws_lb_listener.listener]
}

resource "aws_ecs_task_definition" "storage-service-task-definition" {
    family                              = "test-family"
    # container definitions describes the configurations for the task
    container_definitions               = jsonencode(
    [
    {
        "name"                          : "${var.storage_service_name}",
        "image"                         : "${var.storage_image_url}:${var.storage_image_tag}",
        "command"                       : ["CMD", "wget", "--no-verbose", "--tries=1", "--spider", "http://localhost:5000/status"],
        "essential"                     : true,
        "networkMode"                   : "awsvpc",
        "portMappings"                  : [
                                            {
                                                "containerPort" : var.storage_service_container_port,
                                                "hostPort"      : var.storage_service_container_port,
                                            }
                                          ]
    }
    ] 
    )
    requires_compatibilities            = ["FARGATE"]
    network_mode                        = "awsvpc"
    cpu                                 = "256"
    memory                              = "512"
    execution_role_arn                  = aws_iam_role.ecsTaskExecutionRole.arn
    task_role_arn                       = aws_iam_role.ecsTaskRole.arn
}

resource "aws_ecs_service" "storage_ecs_service" {
    name                                = "${var.storage_service_name}"
    cluster                             = aws_ecs_cluster.ecs_cluster.arn
    task_definition                     = aws_ecs_task_definition.storage-service-task-definition.arn
    launch_type                         = "FARGATE"
    scheduling_strategy                 = "REPLICA"
    desired_count                       = var.storage_service_instance_count # the number of tasks you wish to run

  network_configuration {
    subnets                             = [aws_subnet.private_subnet_1.id , aws_subnet.private_subnet_2.id]
    assign_public_ip                    = false
    security_groups                     = [aws_security_group.ecs_sg.id, aws_security_group.alb_sg.id]
  }

# This block registers the tasks to a target group of the loadbalancer.
  load_balancer {
    target_group_arn                    = aws_lb_target_group.target_group.arn #the target group defined in the alb file
    container_name                      = "${var.storage_service_name}"
    container_port                      = var.storage_service_container_port
  }
  depends_on                            = [aws_lb_listener.listener]
}

resource "aws_ecs_task_definition" "postgresmeta-service-task-definition" {
    family                              = "test-family"
    # container definitions describes the configurations for the task
    container_definitions               = jsonencode(
    [
    {
        "name"                          : "${var.postgresmeta_service_name}",
        "image"                         : "${var.postgresmeta_image_url}:${var.postgresmeta_image_tag}",
        "essential"                     : true,
        "networkMode"                   : "awsvpc",
        "portMappings"                  : [
                                            {
                                                "containerPort" : var.postgresmeta_service_container_port,
                                                "hostPort"      : var.postgresmeta_service_container_port,
                                            }
                                          ]
    }
    ] 
    )
    requires_compatibilities            = ["FARGATE"]
    network_mode                        = "awsvpc"
    cpu                                 = "256"
    memory                              = "512"
    execution_role_arn                  = aws_iam_role.ecsTaskExecutionRole.arn
    task_role_arn                       = aws_iam_role.ecsTaskRole.arn
}

resource "aws_ecs_service" "postgresmeta_ecs_service" {
    name                                = "${var.postgresmeta_service_name}"
    cluster                             = aws_ecs_cluster.ecs_cluster.arn
    task_definition                     = aws_ecs_task_definition.postgresmeta-service-task-definition.arn
    launch_type                         = "FARGATE"
    scheduling_strategy                 = "REPLICA"
    desired_count                       = var.postgresmeta_service_instance_count # the number of tasks you wish to run

  network_configuration {
    subnets                             = [aws_subnet.private_subnet_1.id , aws_subnet.private_subnet_2.id]
    assign_public_ip                    = false
    security_groups                     = [aws_security_group.ecs_sg.id, aws_security_group.alb_sg.id]
  }

# This block registers the tasks to a target group of the loadbalancer.
  load_balancer {
    target_group_arn                    = aws_lb_target_group.target_group.arn #the target group defined in the alb file
    container_name                      = "${var.postgresmeta_service_name}"
    container_port                      = var.postgresmeta_service_container_port
  }
  depends_on                            = [aws_lb_listener.listener]
}
