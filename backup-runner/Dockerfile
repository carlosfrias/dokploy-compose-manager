FROM alpine:3.20

# ── APK packages ────────────────────────────────────────────────────────────────
RUN apk add --no-cache \
        python3 \
        py3-pip \
        bash \
        openssh-client \
        rsync \
        curl \
        tar \
        gzip \
        postgresql-client \
        mariadb-client \
        pass \
        gnupg \
        jq \
        rclone \
        findutils \
    && rm -rf /var/cache/apk/* /tmp/*

# ── Ansible + collections ────────────────────────────────────────────────────────
RUN pip3 install --no-cache-dir --break-system-packages \
        ansible \
        ansible-core \
    && rm -rf /root/.cache/*

# ── Remove old community.docker (apk version) and install fresh ─────────────────
# apk version (v3.9.0) doesn't register http+docker:// URL scheme properly
RUN rm -rf /usr/lib/python3.12/site-packages/ansible_collections/community/docker \
 && ansible-galaxy collection install community.docker \
 && rm -rf /root/.ansible/tmp/*

# ── Python deps: docker SDK + requests (for Ansible community.docker) ─────────────
COPY install_python_deps.py /tmp/install_python_deps.py
RUN python3 /tmp/install_python_deps.py \
 && rm -f /tmp/install_python_deps.py /tmp/*.whl /tmp/*.json

# ── Startup script ───────────────────────────────────────────────────────────────
COPY startup.sh /startup.sh
COPY ansible.cfg /etc/ansible/ansible.cfg
RUN chmod +x /startup.sh

# Override Alpine's default CMD [/bin/sh]
CMD []
ENTRYPOINT ["/startup.sh"]
