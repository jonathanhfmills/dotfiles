let
  desktop = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBL/rUMYv57bV1xXF0yqA7VT+s63ks9bhu17rGF61Fl1";
  workstation = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDzilsdFCw40sGuO763NNIOk3YrhAb9oXwwMmqL6raMO";
  nas = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMhrL9KhdflQy9fkrNfLG7UGkhfKGg6Hru/mUIzXf+YN";
  portable = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFuaCnIaDtaxLt1itAmJYI+1oU/J/XXqrqWJNmbGVEHQ";
  allHosts = [ desktop workstation nas portable ];
in {
  "password-jon.age".publicKeys = allHosts;
  "caddy-cloudflare-token.age".publicKeys = [ workstation nas ];
}
