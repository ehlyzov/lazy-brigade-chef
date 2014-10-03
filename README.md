lazy-brigade-chef
=================

lazy chef recipe for preparing server for rails application and (optional) generate deploy script.

Application domain **must** be configured, application user and application environment *can* be configured.

If you want to use `lazy-brigade::deploy` you also have to specify application repo url.

If you want to protect site using http auth, set app-protected attributed to true and specify `auth_user` and `auth_hash` (as for htpasswd).

Protected content (e.g. `secret.yml`) should be defined in environment file.
