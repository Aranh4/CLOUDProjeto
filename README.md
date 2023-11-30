# Implementação de Arquitetura Cloud na AWS com Terraform

## Objetivo: 
 Provisionar uma arquitetura na AWS utilizando o Terraform, que englobe o uso de um Application Load Balancer (ALB), instâncias EC2 com Auto Scaling e um banco de dados RDS.

## Arquitetura:

### -Virtual Private Cloud

A Virtual Private Cloud (Nuvem Virtual Privada) é o fator principal na criação da arquitetura na AWS, já que é por meio dela que os outros recursos serão criados. A VPC é criada sempre em uma das regiões provisionadas pela AWS, e no escopo deste projeto, visando manter um custo baixo, a regiao escolhida foi a us-east-1, hospedada na Virgínia do Norte, devido ao seu preço acessível. Para o CIDR da rede, foi escolhido 10.0.0.0/16, esta escolha proporciona uma ampla gama de IPs, garantindo versatilidade para criação de recursos que necessitam de associação a IPs (instâncias e sub-redes). 

Foram criadas 2 sub-redes públicas e 2 privadas, para que seja possível hospedar respectivamente a aplicação e o banco de dados, contudo esse valor pode ser expandido com uma mudança no arquivo variables.tf, que define as váriaveis, sem a necessidade da alteração do arquivo principal que contem as instruções para a construção da arquitetura. As sub-redes públicas foram criadas com CIDRs 10.0.10.0/24 e 10.0.11.0/24 e as privadas com CIDRs 10.0.20.0/24 e 10.0.21.0/24. Para as availability zones (zonas de disponibilidade), foi decidido hospedar cada uma das redes públicas em zonas diferentes e cada uma das redes privadas em zonas diferentes também, filtrando por zonas que estão disponíveis no momento da criação da arquitetura.

Também foram criados um gateway, para que a VPC fosse capaz de se comunicar com  a internet e tabelas de rota, para associar as sub-redes à VPC e possibilitar que as sub-redes pública tivessem acesso a internet, contudo deixando as privadas sem esse acesso. Destaca-se que a AWS permite a comunicação entre sub-redes associadas a um mesmo VPC, assim não sendo necessária a criação de um recurso para permitir a conexão das su-redes privadas com as públicas (NAT Gateway).

### - Application Load Balancer

O propósito do Load Balancer é garantir a distribuição de tráfego entre instâncias para evitar sobrecarregar uma instância ou para encaminhar tipos de requisições diferentes para instâncias diferentes. Para definir quais tipos de comunicação com o Load Balancer serão permissíveis, um security group (grupo de segurança) foi criado. Esse security group é é capaz de especificar as regras de comunicação para entrada e saída. Para que o Load balancer seja acessível para a internet, foi determinado que a comunicação de entrada é permitida na porta 80 pelo protocolo HTTP para qualquer CIDR.

O Load Balancer recebeu as sub-redes públicas e o gateway criados anteriormente como parâmetro, para que ele seja capaz de acessar availability zones diferentes e para garantir conexã com a internet, respectivamente. Também é necessária a criação de um target group (grupo alvo) responsável por direcionar o tráfego para as instâncias e realizar o health check para assegurar que o Load Balancer não distrubuirá treáfego para uma instância não saudável.