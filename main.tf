resource "aws_vpc" "main" {
  cidr_block       = var.vpc_cidr
  instance_tenancy = "default"
  enable_dns_hostnames = true

  tags = local.vpc_final_tags
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id # VPC association

  tags = local.igw_final_tags
}

# Public Subnets
resource "aws_subnet" "public" {
  count = length(var.public_subnet_cidrs)
  vpc_id     = aws_vpc.main.id
  cidr_block = var.public_subnet_cidrs[count.index]
  availability_zone = local.az_names[count.index]
  map_public_ip_on_launch = true

  tags = merge(
        local.common_tags,
        # roboshop-dev-public-us-east-1a
        {
            Name = "${var.project}-${var.environment}-public-${local.az_names[count.index]}"
        },
        var.public_subnet_tags
    )
}

#Private Subnets
resource "aws_subnet" "private" {
  count  = length(var.private_subnet_cidrs)
  vpc_id     = aws_vpc.main.id
  cidr_block = var.private_subnet_cidrs[count.index]
  availability_zone = local.az_names[count.index]


  tags = merge(
      local.common_tags,
     #roboshop-dev-private-us-east-1a
     {
      Name = "${var.project}-${var.environment}-private-${local.az_names[count.index]}"
     },
     var.private_subnet_tags
  )

}

  #Database  Subnets

  resource "aws_subnet" "database"{
  count  = length(var.database_subnet_cidrs)
  vpc_id     = aws_vpc.main.id
  cidr_block = var.database_subnet_cidrs[count.index]
  availability_zone = local.az_names[count.index]


  tags = merge(
      local.common_tags,
     #roboshop-dev-private-us-east-1a
     {
      Name = "${var.project}-${var.environment}-private-${local.az_names[count.index]}"
     },
     var.private_subnet_tags
  )
  }


resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  tags = merge(
    local.common_tags,
    #roboshop-dev-public
    {
      Name = "${var.project}-${var.environment}-public"
    },
    var.public_route_table_tags
  )

}
 
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  tags = merge(
    local.common_tags,
    #roboshop-dev-private
    {
      Name = "${var.project}-${var.environment}-private"
    },
    var.private_route_table_tags
  )

}

 resource "aws_route_table" "database" {
  vpc_id = aws_vpc.main.id

  tags = merge(
    local.common_tags,
    #roboshop-dev-database
    {
      Name = "${var.project}-${var.environment}-database"
    },
    var.database_route_table_tags
  )

}
 

resource "aws_route" "public" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.main.id
}

resource "aws_eip" "nat" {
  domain   = "vpc"
  
  tags = merge(
        local.common_tags,
        {
            Name = "${var.project}-${var.environment}-nat"
        },
        var.eip_tags
  )
}


resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id # We are creating in us-east-1a AZ

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project}-${var.environment}"
    },
    var.nat_gateway_tags
  )
  #To ensure proper ordering it is recomended to add an dependency
  #on the internet Gateway for the vpc

  depends_on =[aws_internet_gateway.main]
}


resource "aws_route" "private" {
  route_table_id         = aws_route_table.private.id # The route table for the private subnet(s)
  destination_cidr_block = "0.0.0.0/0"                # Directs all traffic to the NAT Gateway
  nat_gateway_id         = aws_nat_gateway.main.id 

}

resource "aws_route" "database" {
  route_table_id         = aws_route_table.database.id # The route table for the private subnet(s)
  destination_cidr_block = "0.0.0.0/0"                # Directs all traffic to the NAT Gateway
  nat_gateway_id         = aws_nat_gateway.main.id 

}


# Route table association for a private subnet (ensure traffic uses the correct route table)
resource "aws_route_table_association" "public" {
  count = length (var.public_subnet_cidrs)
  subnet_id      = aws_subnet.public[count.index].id # Example private subnet
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  count = length (var.private_subnet_cidrs)
  subnet_id      = aws_subnet.private[count.index].id # Example private subnet
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "database" {
  count = length (var.database_subnet_cidrs)
  subnet_id      = aws_subnet.database[count.index].id # Example private subnet
  route_table_id = aws_route_table.database.id
}