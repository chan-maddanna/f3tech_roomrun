# Upgrade to a latest stable image instead of using release candidates (aka: rc* )
# To benefit from the latest vulnerability fixes while still having a stable base image to run from.
FROM golang:1.19
# Perhaps id you do not need a bulky build, we can go for somethign like alpine
# But that is upto developers and architects to discuss and decide

# Remove packages that have Vulnerabilities and are not needed for our application
RUN apt-get remove -y python3.9 python3.9-minimal; \
    apt-get remove -y openssh-client; \
    apt-get remove -y ncurses-bin ncurses-base libncursesw6 libncurses6; \
    apt-get update

# Remove cache and clean up
# remove unnecessary packages that is no more needed
# clean up
RUN rm -rf /var/cache/apt/archives; \
    rm -rf /var/lib/apt/lists/*; \
    apt-get purge -y --auto-remove; \
    apt-get autoremove; \
    apt-get clean;

#############################
# @PS Note : The following items are out of scope for now, but just general recommendations of evolving industry bestpractices.
# - Going forward it is recommended to integrate a quality linter for Dockerfiles (Example: https://hadolint.github.io/hadolint/ )
# - Additionally it is recommended that a transparent container image linter also runs as part of CI, preferably on a push-hook
# that lints the container image. (example: https://github.com/goodwithtech/dockle)
#############################

ADD ./ /src
RUN useradd -d /src builder && chown -R builder /src
WORKDIR /src
RUN go install github.com/form3tech/innsecure/cmd/innsecure
EXPOSE 8080

# Switch to limited application user, as we do not need to run as root
USER builder
ENTRYPOINT ["innsecure"]
