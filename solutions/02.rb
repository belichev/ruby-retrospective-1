class Song
  attr_accessor :name, :artist, :genre, :subgenre, :tags
  def initialize(song_as_string, artist_tags)
    @name, @artist, @genre, @tags = song_as_string.split(/\s*\.\s*/)
    @genre, @subgenre = @genre.split(/\s*\,\s*/)
    @tags = @tags ? @tags.split(/\s*\,\s*/) : []
    @tags << @genre.downcase
    @tags << @subgenre.downcase if @subgenre
    @tags |= artist_tags[@artist] if artist_tags[@artist]
  end
end

class Collection
  def initialize(songs_as_string, artist_tags)
    @songs = []
    songs_as_string.each_line { |s| @songs << Song.new(s.strip, artist_tags) }
  end
  
  def find(criteria = {})
    songs = @songs
    songs = find_tags(Array(criteria[:tags]), songs) if criteria[:tags]
    songs = find_artist(criteria[:artist], songs) if criteria[:artist]
    songs = find_name(criteria[:name], songs) if criteria[:name]
    songs = songs.select(&criteria[:filter]) if criteria[:filter]
    songs
  end
  
  def find_tags(tags_string, array)
    tags_select = tags_string.reject { |tag| tag.end_with?('!') }
    tags_reject = tags_string.select { |tag| tag.end_with?('!') }
    tags_reject = tags_reject.map { |tag| tag.chop }
    array = array.select { |song| include_tags?(song.tags, tags_select) }
    array = array.reject { |song| include_tags?(song.tags, tags_reject) }
    array
  end
  
  def include_tags?(song_tags, tags)
    tags != [] ? tags.all? { |tag| song_tags.include? tag } : false
  end
  
  def find_artist(artist_string, array)
    array.select { |song| song.artist == artist_string }
  end
  
  def find_name(name_string, array)
    array.select { |song| song.name == name_string }
  end
end