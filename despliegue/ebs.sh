#!/bin/bash

echo "Que desea hacer?"

echo "1) Crear un nuevo entorno"

echo "2) Actualizar el entorno"

read -p "-> " cv

if [ $cv -eq 1 ]; then

    compsb3g=$(aws s3 ls | grep amzn-s3-entorno-green | wc -l)  

    if [ $compsb3g -eq 0 ]; then

        aws s3api create-bucket \
            --bucket amzn-s3-entorno-greenacp \
            --region us-east-1 
    fi
    compszip3g=$(aws s3 ls amzn-s3-entorno-greenacp | grep .zip$ | wc -l)


    if [ $compszip3g -eq 0 ]; then

        echo "No hay ningun .zip en ese bucket"

        read -p "Zip que se subira al bucket -> " zip


        if [ -f $zip ]; then

            if [[ "$zip" = *.zip ]]; then

                aws s3 cp $zip s3://amzn-s3-entorno-greenacp/green.zip

            else

                echo "El fichero $1 no es un .zip"
            fi        

        else

            echo "El fichero $1 no existe"

        fi
    fi
    aws elasticbeanstalk create-application-version \
        --application-name alex-app-cli \
        --version-label v1 \
        --description "Entorno Green" \
        --source-bundle S3Bucket="amzn-s3-entorno-greenacp",S3Key="green.zip" \
        --auto-create-application

    echo "Se ha creado la aplicacion alex-app-cli v1"

    aws elasticbeanstalk create-environment \
        --application-name alex-app-cli \
        --environment-name alex-env-cli \
        --cname-prefix alex-app-cli \
        --version-label v1 \
        --solution-stack-name "64bit Amazon Linux 2023 v4.7.8 running PHP 8.4" \
        --option-settings Namespace=aws:autoscaling:launchconfiguration,OptionName=IamInstanceProfile,Value=LabInstanceProfile
    echo "Se ha creado el entorno alex-env-cli"


elif [ $cv -eq 2 ]; then

    echo "Comandos blue"

else

    echo "Solo debe elegir uno de los 2 numeros que se han mostrado"

fi

exit 0

