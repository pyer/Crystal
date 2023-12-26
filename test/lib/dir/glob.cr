require "test"

class DirGlobTest < Test

  private def datapath(*components)
    File.join("test", "data", *components)
  end

#  def test_empty_pattern
#    assert_equal([] of String, Dir[""])
#  end

  def test_raw_pattern
    assert_equal(["/"], Dir["/"])
    assert_equal(["/tmp"], Dir["/tmp"])
  end

  def test_glob_with_a_single_pattern1
    expected = [
        datapath("dir", "f1.txt"),
        datapath("dir", "f2.txt"),
        datapath("dir", "g2.txt"),
      ]
    result = [] of String
    Dir.glob("#{datapath}/dir/*.txt") do |filename|
      result << filename
    end
    assert_equal(expected, result.sort)
    assert_equal(expected, Dir["#{datapath}/dir/*.txt"].sort)
    assert_equal(expected, Dir["#{datapath}///dir////*.txt"].sort)
  end

  def test_glob_with_a_single_pattern2
    expected = [
        datapath("dir", "dots"),
        datapath("dir", "f1.txt"),
        datapath("dir", "f2.txt"),
        datapath("dir", "f3.txx"),
        datapath("dir", "g2.txt"),
        datapath("dir", "subdir"),
        datapath("dir", "subdir2"),
      ].sort
    assert_equal(expected, Dir["#{datapath}/dir/*"].sort)
    assert_equal(expected, Dir["#{datapath}/dir/**"].sort)
  end

  def test_glob_with_a_single_pattern3
    expected = [
        datapath("dir", "dots", ""),
        datapath("dir", "subdir", ""),
        datapath("dir", "subdir2", ""),
      ].sort
    assert_equal(expected, Dir["#{datapath}/dir/*/"].sort)
  end

  def test_glob_with_multiple_patterns
    expected = [
        datapath("dir", "f1.txt"),
        datapath("dir", "f2.txt"),
        datapath("dir", "g2.txt"),
        datapath("dir", "subdir", "f1.txt"),
      ]
    assert_equal(expected, Dir["#{datapath}/dir/*.txt", "#{datapath}/dir/subdir/*.txt"].sort)
  end

  def test_recursive_glob
    expected = [
        datapath("dir", "f1.txt"),
        datapath("dir", "f2.txt"),
        datapath("dir", "g2.txt"),
        datapath("dir", "subdir", "f1.txt"),
        datapath("dir", "subdir", "subdir2", "f2.txt"),
      ].sort
    expected_file = [datapath("dir", "subdir/subdir2/f2.txt")]

    assert_equal(expected, Dir["#{datapath}/dir/**/*.txt"].sort)

    assert_equal(expected_file, Dir["#{datapath}/dir/**/subdir2/f2.txt"])
    assert_equal(expected_file, Dir["#{datapath}/dir/**/subdir2/*.txt"])
  end

#  def test_double_recursive_glob
#    path = tmp_path("glob-double-recurse")
#    Dir.mkdir_p path
#    Dir.cd(path) do
#      p1 = Path["x", "a", "x", "c"]
#      p2 = Path["x", "a", "x", "a", "x", "c"]
#      expected = [p1.to_s, p2.to_s]
#
#      Dir.mkdir_p p1
#      Dir.mkdir_p p2
#      assert_equal(expected, Dir["**/a/**/c"].sort)
#    end
#  end

  def test_recursive_glob1
    expected = [
        datapath("dir", "f1.txt"),
        datapath("dir", "f2.txt"),
        datapath("dir", "f3.txx"),
      ].sort
    assert_equal(expected, Dir["#{datapath}/dir/f?.tx?"].sort)
  end

  def test_recursive_glob2
    expected = [
        datapath("dir", "f1.txt"),
        datapath("dir", "f2.txt"),
        datapath("dir", "g2.txt"),
        datapath("dir", "subdir", "f1.txt"),
      ].sort
    assert_equal(expected, Dir["#{datapath}/{dir,dir/subdir}/*.txt"].sort)
  end

  def test_recursive_glob3
    expected = [
        datapath("dir", "f1.txt"),
        datapath("dir", "f2.txt"),
        datapath("dir", "f3.txx"),
        datapath("dir", "g2.txt"),
        datapath("dir", "subdir", "f1.txt"),
        datapath("dir", "subdir", "subdir2", "f2.txt"),
      ].sort
    assert_equal(expected, Dir["#{datapath}/dir/{**/*.txt,**/*.txx}"].sort)
  end

  def test_recursive_glob4
    expected = [
        datapath("dir", "f1.txt"),
        datapath("dir", "f2.txt"),
        datapath("dir", "g2.txt"),
      ]
    assert_equal(expected, Dir["#{datapath}/dir/{?1.*,{f,g}2.txt}"].sort)
  end

  def test_recursive_glob5
    expected = [
        datapath("dir", "f1.txt"),
        datapath("dir", "f2.txt"),
        datapath("dir", "f3.txx"),
        datapath("dir", "g2.txt"),
      ]
    assert_equal(expected, Dir["#{datapath}/dir/{f,g}{1,2,3}.tx{t,x}"].sort)
  end

  def test_recursive_glob6
    expected = [
        datapath("dir", "f1.txt"),
        datapath("dir", "f2.txt"),
        datapath("dir", "g2.txt"),
      ]
    assert_equal(expected, Dir["#{datapath}/dir/[a-z]?.txt"].sort)
  end

  def test_relative_paths1
    expected = [
        "./test/data/dir/dots/",
        "./test/data/dir/subdir/",
        "./test/data/dir/subdir2/",
      ]
    assert_equal(expected, Dir["./test/data/dir/*/"].sort)
  end

  def test_relative_paths2
    expected = [
        "../data/dir/dots/",
        "../data/dir/subdir/",
        "../data/dir/subdir2/",
      ]
    Dir.cd("test/data") do
      assert_equal(expected, Dir["../data/dir/*/"].sort)
    end
  end

  def test_relative_paths3
    expected = [
        datapath("dir", "dots", ""),
        datapath("dir", "subdir", ""),
        datapath("dir", "subdir2", ""),
      ]
    assert_equal(expected, Dir["**/dir/*/"].sort)
  end

  def test_symlinks
    link = "dir/f1_link.txt"
    non_link = "dir/non_link.txt"

    Dir.cd(datapath) do
      File.symlink("dir/f1.txt", link)
      File.symlink("dir/nonexisting", non_link)
      assert_equal([link, non_link], Dir["dir/*_link.txt"])
      assert_equal([non_link], Dir["dir/non_link.txt"])
      File.delete(link)
      File.delete(non_link)
    end
  end

  def test_symlink_dir
    link_dir = "dir/glob/dir"

    Dir.cd(datapath) do
      Dir.mkdir("dir/glob")
      File.symlink("../subdir", link_dir)
      assert_equal([] of String, Dir.glob("dir/glob/*/f1.txt"))
      assert_equal(["dir/glob/dir/f1.txt"], Dir.glob("dir/glob/*/f1.txt",follow_symlinks: true))
      File.delete(link_dir)
      Dir.delete("dir/glob")
    end
  end

  def test_pattern_ending_with_dot
    expected = [
        datapath("dir", "dots", "."),
        datapath("dir", "subdir", "."),
        datapath("dir", "subdir2", "."),
      ]
    assert_equal([datapath("dir", ".")], Dir["#{datapath}/dir/."].sort)
    assert_equal(expected, Dir["#{datapath}/dir/*/."].sort)
  end

  def test_pattern_ending_with_dots
    expected = [
        datapath("dir", "dots", ".."),
        datapath("dir", "subdir", ".."),
        datapath("dir", "subdir2", ".."),
      ]
    assert_equal([datapath("dir", "..")], Dir["#{datapath}/dir/.."].sort)
    assert_equal(expected, Dir["#{datapath}/dir/*/.."].sort)
  end

  def test_matches_hidden_files
    expected = [
        datapath("dir", "dots", ".dot.hidden"),
        datapath("dir", "dots", ".hidden"),
        datapath("dir", "dots", ".hidden", "f1.txt"),
      ].sort
    assert_equal(expected, Dir.glob("#{datapath}/dir/dots/**/*", match: :dot_files).sort)
    assert_equal(expected, Dir.glob("#{datapath}/dir/dots/**/*", match_hidden: true).sort)
  end

  def test_ignores_hidden_files
    # ignores hidden files
    assert_empty  Dir.glob("#{datapath}/dir/dots/*", match: :none)
    assert_empty  Dir.glob("#{datapath}/dir/dots/*", match_hidden: false)
    # ignores hidden files recursively
    assert_empty  Dir.glob("#{datapath}/dir/dots/**/*", match: :none)
    assert_empty  Dir.glob("#{datapath}/dir/dots/**/*", match_hidden: false)
  end

end

