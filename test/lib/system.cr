require "test"

class SystemTest < Test

  def test_cpu_count
    shell_cpus = `grep -sc '^processor' /proc/cpuinfo`.to_i
    cpu_count = System.cpu_count
    assert_equal(shell_cpus, cpu_count)
  end

  def test_hostname
    shell_hostname = `hostname`.strip
    hostname = System.hostname
    assert_equal(shell_hostname, hostname)
  end

end
