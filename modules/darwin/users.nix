{username, ...}: {
  users.users."${username}" = {
    home = "/Users/${username}";
    description = username;
  };
}
