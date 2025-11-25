#!/bin/bash

echo "Que desea hacer?"

echo "1) Crear un nuevo entorno"

echo "2) Actualizar el entorno"

read -p "-> " cv

if [ $cv -eq 1 ]; then

    compsb3g=$(aws s3 ls | grep amzn-s3-entorno-green | wc -l)    

    while [ $compsb3g -eq 0 ]; do

        aws s3api create-bucket \
            --bucket amzn-s3-entorno-green-acp \
            --region us-east-1

        compsb3g=$(aws s3 ls | grep amzn-s3-entorno-green | wc -l)

    done

    compszip3g=$(aws s3 ls amzn-s3-entorno-green-acp | grep .zip$ | wc -l)


    while [ $compszip3g -eq 0 ]; do

        read -p "Zip que se subira al bucket -> " zip


        if [ -f $zip ]; then

            if [[ "$zip" = *.zip ]]; then

                aws s3 cp $zip s3://amzn-s3-entorno-green-acp/green.zip
                compszip3g=$(aws s3 ls amzn-s3-entorno-green-acp | grep .zip$ | wc -l)

            else

                echo "El fichero $zip no es un .zip"
            fi        

        else

            echo "El fichero $zip no existe"

        fi
    done
    aws elasticbeanstalk create-application-version \
        --application-name alex-app-cli \
        --version-label v1 \
        --description "Entorno Green" \
        --source-bundle S3Bucket="amzn-s3-entorno-green-acp",S3Key="green.zip" \
        --auto-create-application



    aws elasticbeanstalk create-environment \
        --application-name alex-app-cli \
        --environment-name alex-env-cli \
        --cname-prefix alex-app-cli \
        --version-label v1 \
        --solution-stack-name "64bit Amazon Linux 2023 v4.7.8 running PHP 8.4" \
        --option-settings Namespace=aws:autoscaling:launchconfiguration,OptionName=IamInstanceProfile,Value=LabInstanceProfile



elif [ $cv -eq 2 ]; then

    compenv=$(aws elasticbeanstalk describe-environments \
        --application-name "alex-app-cli" \
        --output text | wc -l)

    if [ $compenv -ne 0 ]; then
        compsb3b=$(aws s3 ls | grep amzn-s3-entorno-blue | wc -l)    

        while [ $compsb3b -eq 0 ]; do

        aws s3api create-bucket \
            --bucket amzn-s3-entorno-blue-acp \
            --region us-east-1

        compsb3b=$(aws s3 ls | grep amzn-s3-entorno-blue | wc -l)

    done

    compszip3b=$(aws s3 ls amzn-s3-entorno-blue-acp | grep .zip$ | wc -l)


    while [ $compszip3b -eq 0 ]; do

        read -p "Zip que se subira al bucket -> " zip


        if [ -f $zip ]; then

            if [[ "$zip" = *.zip ]]; then

                aws s3 cp $zip s3://amzn-s3-entorno-blue-acp/blue.zip
                compszip3b=$(aws s3 ls amzn-s3-entorno-blue-acp | grep .zip$ | wc -l)

            else

                echo "El fichero $zip no es un .zip"
            fi        

        else

            echo "El fichero $zip no existe"

        fi
    done
        

    else

        echo "El entorno no existe, por favor, hagalo"
    
    fi

else

    echo "Solo debe elegir uno de los 2 numeros que se han mostrado"

fi

exit 0

