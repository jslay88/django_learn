# syntax=docker/dockerfile:1.4
FROM python:3-alpine as base

# Ensure that the environment uses UTF-8 encoding by default
ENV LANG en_US.UTF-8
# Disable pip cache dir
ENV PIP_NO_CACHE_DIR true
# Stops Python default buffering to stdout, improving logging to the console.
ENV PYTHONUNBUFFERED 1
ENV APP_HOME /src
ENV APP_NAME django_learn

WORKDIR ${APP_HOME}

# Install and update common OS packages, pip, setuptools, wheel, and awscli
RUN apk update --no-cache && apk upgrade --no-cache
RUN pip install --upgrade pip setuptools wheel

#######################################################################
# Intermediate layer to build only prod deps
FROM base as python-builder

# Install python requirements
COPY requirements requirements
RUN mkdir /build && pip install --prefix=/build -r requirements/base.txt

#######################################################################
# dev is used for local development, as well as a base for frontend.
FROM python-builder AS dev

ENV PYTHONPATH ${APP_HOME}/${APP_NAME}
# Django Settings
ENV DJANGO_SETTINGS_MODULE ${APP_NAME}.settings.dev

# .backend-deps and .frontend-deps are required to run the application
RUN apk add --no-cache --virtual .backend-deps postgresql-client

# Install python requirements
COPY requirements requirements
# RUN cp -Rfp /build/* /usr/local && rm -Rf /build && pip install -r requirements/local.txt
RUN cp -Rfp /build/* /usr/local && rm -Rf /build

EXPOSE 8000

# Start app using development server
ENTRYPOINT ["./docker-entrypoint.sh"]
CMD ["sh", "-c", "python $APP_NAME/manage.py runserver 0.0.0.0:8000"]

#######################################################################
# prod layer
FROM base as prod

ARG USER_UID=1000
ARG USER_GID=$USER_UID
ARG USERNAME=django

ENV PYTHONPATH ${APP_HOME}/${APP_NAME}

ENV DJANGO_SETTINGS_MODULE ${APP_NAME}.settings.base

# Convert sercrets to environment variables
COPY <<EOF /etc/profile.d/secrets_env.sh
if [ -d /var/run/secrets ]; then
    for s in $(find -L /var/run/secrets/$APP_NAME -type f); do
        export $(basename \$s)=$(cat \$s);
    done
fi
EOF

# Copy Python requirements from builder layer
COPY --from=python-builder /build /usr/local

# Cleanup *.key files
RUN for i in $(find /usr/local/lib/python3* -type f -name "*.key*"); do rm "$i"; done

# .backend-deps are required to run the application
RUN apk add --no-cache --virtual .backend-deps bash curl postgresql-client

# Create non-root user
RUN addgroup -S -g $USER_GID $USERNAME \
    && adduser -S -u $USER_UID $USERNAME $USERNAME \
    && chown -Rf $USER_UID:$USER_GID ${APP_HOME}
USER $USERNAME

# Copy code
COPY --chown=$USER_UID:$USER_GID . .
RUN chmod +x *.sh

# Setup healthcheck
HEALTHCHECK --start-period=300s --interval=30s --retries=30 \
    CMD curl -sf -A docker-healthcheck -o /dev/null http://localhost:8000/ht/

# Start app using gunicorn
ENTRYPOINT ["./docker-entrypoint.sh"]
CMD ["gunicorn", "-c", "gunicorn_conf.py"]
