require "test"

class DirTest < Test

  def setup
    Dir.mkdir(tmp_path, 0o700)
  end

  def teardown
    Dir.delete(tmp_path)
  end

  private def datapath(*components)
    File.join("test", "data", *components)
  end

  private def tmp_path(*components)
    File.join("test", "tmp", *components)
  end

  def test_existent_directory
    assert Dir.exists?(tmp_path)
    assert Dir.exists?(datapath)
    assert Dir.exists?(datapath("dir"))
    Dir.open(datapath) do |dir|
      info = dir.info
      assert info.directory?
    end
  end

  def test_nonexistent_directory
    refute Dir.exists?(datapath("dir", "f1.txt"))
    refute Dir.exists?(datapath("foo", "bar"))
    refute Dir.exists?(datapath("dir", "f1.txt", "/"))
  end

  def test_empty_directory
    assert Dir.empty?(tmp_path)
    refute Dir.empty?(datapath)
    # tests empty? on nonexistent directory
    assert_raises(File::NotFoundError) do
      Dir.empty?(datapath("foo", "bar"))
    end
    # tests empty? on a directory path to a file
    assert_raises(File::Error) do
      Dir.empty?(datapath("dir", "f1.txt", "/"))
    end
  end

  def test_mkdir_and_delete
    path=tmp_path("directory")
    Dir.mkdir(path, 0o700)
    assert Dir.exists?(path)
    Dir.delete(path)
    refute Dir.exists?(path)
  end

  def test_mkdir_and_deleteq
    path=tmp_path("directory")
    Dir.mkdir(path, 0o700)
    assert Dir.exists?(path)
    assert Dir.delete?(path)
    refute Dir.exists?(path)
    refute Dir.delete?(path)
  end

  def test_mkdir_existing_path
    assert_raises(File::AlreadyExistsError) do
      Dir.mkdir(datapath, 0o700)
    end
  end

  def test_mkdir_p
    assert Dir.exists?(tmp_path)
    path = tmp_path("a", "b", "c")
    Dir.mkdir_p(path)
    assert Dir.exists?(path)
    Dir.delete(path)
    Dir.delete(tmp_path("a", "b"))
    Dir.delete(tmp_path("a"))
  end

  def test_mkdir_p_existing_file
    assert File.exists?(datapath("test_file.txt"))
    assert_raises(File::AlreadyExistsError) do
      Dir.mkdir_p(datapath("test_file.txt"))
    end
  end

  def test_mkdir_p_existing_path
    path = File.join(datapath, "dir")
    assert Dir.exists?(path)
    Dir.mkdir_p(path)
    assert Dir.exists?(path)
  end

  def test_delete_nonexistent_path
    refute Dir.exists?(tmp_path("nonexistent"))
    assert_raises(File::NotFoundError) do
      Dir.delete(tmp_path("nonexistent"))
    end
  end

  def test_delete_path_that_cannot_be_removed
    assert_raises(File::Error) do
      Dir.delete(datapath)
    end
  end

  def test_delete_symlink_directory
    target_path=tmp_path("delete-target-directory")
    symlink_path=tmp_path("delete-symlink-directory")
    Dir.mkdir(target_path)
    File.symlink(target_path, symlink_path)
    assert_raises(File::Error) do
      Dir.delete(symlink_path)
    end
    File.delete(symlink_path)
    Dir.delete(target_path)
  end

  def test_delete_read_only_directory
    path=tmp_path("delete-readonly-directory")
    Dir.mkdir(path)
    File.chmod(path, 0o440)
    Dir.delete(path)
    refute Dir.exists?(path)
  end


  def test_open_with_new
    filenames = [] of String

    dir = Dir.new(datapath("dir"))
    dir.each do |filename|
      filenames << filename
    end
    dir.close

    assert filenames.includes?("f1.txt")
  end

  def test_open_with_open
    filenames = [] of String

    Dir.open(datapath("dir")) do |dir|
      dir.each do |filename|
        filenames << filename
      end
    end

    assert filenames.includes?("f1.txt")
  end

  def test_init_value
    path = datapath("dir")
    dir = Dir.new(path)
    assert_equal(path, dir.path)
  end

  def test_dir_entries
    filenames = Dir.entries(datapath("dir"))
    assert filenames.includes?(".")
    assert filenames.includes?("..")
    assert filenames.includes?("f1.txt")
  end

  def test_dir_iterator
    filenames = [] of String

    iter = Dir.new(datapath("dir")).each
    iter.each do |filename|
      filenames << filename
    end

    assert filenames.includes?(".")
    assert filenames.includes?("..")
    assert filenames.includes?("f1.txt")
  end

  def test_child_iterator
    filenames = [] of String

    iter = Dir.new(datapath("dir")).each_child
    iter.each do |filename|
      filenames << filename
    end

    refute filenames.includes?(".")
    refute filenames.includes?("..")
    assert filenames.includes?("f1.txt")
  end

  def test_double_close
    dir = Dir.open(datapath("dir")) do |dir|
      dir.close
      dir.close
    end
  end

  def test_current_dir
    pwd = `pwd`.chomp
    assert_equal(pwd, Dir.current)
  end

  def test_cd
    cwd = Dir.current
    Dir.cd("..")
    refute_equal(cwd, Dir.current)
    Dir.cd(cwd)
    assert_equal(cwd, Dir.current)

    Dir.cd(Path.new(".."))
    refute_equal(cwd, Dir.current)
    Dir.cd(cwd)
    assert_equal(cwd, Dir.current)

    Dir.cd(Path.new("..")) do
      refute_equal(cwd, Dir.current)
    end
    assert_equal(cwd, Dir.current)

    Dir.cd("..") do
      refute_equal(cwd, Dir.current)
    end
    assert_equal(cwd, Dir.current)

    assert_raises(File::NotFoundError) do
      Dir.cd("/nope")
    end
  end

  def test_tempdir
    assert_equal("/tmp", Dir.tempdir)

    tmp_path = Path["my_temporary_path"].expand.to_s
    ENV["TMPDIR"] = tmp_path
    assert_equal(tmp_path, Dir.tempdir)
  end

  def test_raises_an_error_on_null_byte
    assert_raises(ArgumentError) do
      Dir.new("foo\0bar")
      Dir.cd("foo\0bar")
      Dir.exists?("foo\0bar")
      Dir.mkdir("foo\0bar")
      Dir.mkdir_p("foo\0bar")
      Dir.delete("foo\0bar")
    end
  end

end
