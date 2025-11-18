#!/bin/bash

echo "Que desea hacer?"

echo "1) Crear un nuevo entorno"

echo "2) Actualizar el entorno"

read cv

if [ $cv -eq 1 ]; then
                    comps3g=$()
                    aws s3api create-bucket \
                        --bucket amzn-s3-entorno-green \
                        --region us-east-1
                        aws s3 cp $1 s3://amzn-s3-entorno-green/green.zip

                        aws elasticbeanstalk create-application-version \
                            --application-name alex-app-cli \
                            --version-label v1 \
                            --description "Entorno Green" \
                            --source-bundle S3Bucket="amzn-s3-entorno-green",S3Key="green.zip" \
                            --auto-create-application

                        echo "Se ha creado la aplicacion alex-app-cli v1"

                        aws elasticbeanstalk create-environment \
                            --application-name alex-app-cli \
                            --environment-name alex-env-cli \
                            --cname-prefix alex-app-cli \
                            --version-label v1 \
                            --solution-stack-name "64bit Amazon Linux 2023 v4.7.8 running PHP 8.4"

    

else


    if [ -f $1 ]; then

        if [[ "$1" = *.zip ]]; then




                else
                        echo "aqui creo nueva version"
                fi

        else

            echo "El fichero $1 no es un .zip"
        fi

        

    else

        echo "El fichero $1 no existe"
    fi

fi