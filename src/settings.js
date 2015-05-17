class Settings {
  folder_for(kind) {
    switch (kind) {
      case 'movie':
        return '/Users/apple/mount/public/themoviedb2';
      case 'tvshow':
        return '/Volumes/Raid3/thetvdb';
      case 'porn':
        return '/Users/apple/mount/public/porn';
      default:
        throw 'unknown kinds';
    }
  }
}

var settings = new Settings();

export default settings;
