require "xmlrpc/server"
require "socket"
require 'kmeans-clusterer'



s = XMLRPC::Server.new(ARGV[0])
MAX_NUMBER = 16000
STONE_DIAMETER = 50

class MyAlggago
  def calculate(positions)

    # Write your own codes here
    my_position = positions[0]
    your_position = positions[1]

    clusters = get_cluster(your_position)

    centroids_temp = []
    clusters.each do |cluster|
      centroids_temp.push cluster[1]
    end

    centroids = get_float(centroids_temp)

    big_cluster = 0
    big_cluster_temp = 0

    clusters.each do |cluster|
      if cluster[0] > big_cluster_temp
        big_cluster_temp = cluster[0]
        big_cluster = cluster
      end
    end

    # selected_path = get_shortest_path(my_position, centroids)
    selected_path = get_shortest_path(my_position, big_cluster[2])

    # selected_cluster = 0
    #
    # clusters.each do |cluster|
    #   if cluster.index("#{selected_path[1]}")
    #     selected_cluster = cluster
    #   end
    # end
    selected_cluster = big_cluster[2]
    clusters.delete(selected_cluster)

    selected_centroid = []
    selected_centroid_temp = big_cluster[1].delete('[,]').strip.split(" ")

    selected_centroid_temp.each do |i|
      selected_centroid.push i.to_f
    end

    centroids.delete(selected_centroid)

    selected_stones = get_shortest_path([selected_path[0]], selected_cluster)
    selected_cluster.delete(selected_stones[1])

    if selected_cluster.empty?
      next_stone_weight = [0,0]
    elsif selected_cluster.size == 1
      next_stone_weight = get_next_point_weight(selected_stones[1],centroids)
    else
      next_stone_weight = get_next_point_weight(selected_stones[1], selected_cluster)
    end

    # Return values
    message = get_name
    stone_number = my_position.index(selected_stones[0])

    x_length = selected_stones[1][0] - selected_stones[0][0]
    y_length = selected_stones[1][1] - selected_stones[0][1]

    x_mark = (x_length/x_length.abs)
    y_mark = (y_length/y_length.abs)

    stone_x_strength = (x_length + next_stone_weight[0] * y_mark ) * 100
    stone_y_strength = (y_length + next_stone_weight[1] * x_mark  ) * 100

    return [stone_number, stone_x_strength, stone_y_strength, message]

  end

  def get_name
    "ptptpt!!!" # Set your name or team name
  end

  def rad degrees
    radians = degrees * Math::PI / 180
    return radians
  end

  # def deg radians
  #   degrees =  radians * 180 / Math::PI
  #   return radians
  # end

  # 돌의 충돌한계 각도 계산
  def get_weight_limit_seta(my_stone, your_stone)
    # 돌의 충돌 한계 좌표를 구한 후, 그 좌표와 시작 돌의 좌표를 통해 각도를 다시 구하면 충돌 한계 각도를 구할 수 있다.
    # 각도를 구하는 이유는 같은 방향이라도 좌표가 다를 수 있기 때문에 각 방향을 찾는것이 효율적이다.
    x_length = your_stone[0] - my_stone[0]
    y_length = your_stone[1] - my_stone[1]

    seta = Math.atan2(y_length, x_length)

    x_limit_length_top = (STONE_DIAMETER * Math.cos(seta + rad(90)))
    y_limit_length_top = (STONE_DIAMETER * Math.sin(seta + rad(90)))

    x_limit_length_bottom = (STONE_DIAMETER * Math.cos(seta + rad(270)))
    y_limit_length_bottom = (STONE_DIAMETER * Math.sin(seta + rad(270)))

    limit_seta_top = Math.atan2(y_limit_length_top, x_limit_length_top)
    limit_seta_bottom = Math.atan2(y_limit_length_bottom, x_limit_length_bottom)

    return limit_seta_top, limit_seta_bottom
  end

  # 첫번째 충돌 후 갈 벡터 계산
  def get_weight_value(your_stone, next_point)
    # 다음 지점으로 돌을 굴절시킨다.
    x_len = next_point[0] - your_stone[0]
    y_len = next_point[1] - your_stone[1]
    seta = Math.atan2( y_len, x_len )

    # if x_len > 0 && y_len > 0
    #   x_weight = -(STONE_DIAMETER * Math.cos(-seta))
    #   y_weight = -(STONE_DIAMETER * Math.sin(-seta))
    # # elsif x_len < 0 && y_len > 0
    # # elsif x_len < 0 && y_len < 0
    # # elsif x_len > 0 && y_len < 0
    # else
    x_weight = (STONE_DIAMETER/2 * Math.cos(seta)).abs
    y_weight = (STONE_DIAMETER/2 * Math.sin(seta)).abs

    return x_weight, y_weight
  end

  def get_cluster(stones)
    clusters = []
    cluster_temp = []
    # next_point = 0
    if stones.size > 3
      kmeans = KMeansClusterer.run(stones.size/2, stones, runs: stones.size)
    else
      kmeans = KMeansClusterer.run(stones.size, stones, runs: stones.size)
    end

    kmeans.clusters.each do |cluster|
      clusters.push [cluster.points.size, cluster.centroid.to_s, get_float(cluster.points.to_a)]
    end

    return clusters
  end

  # 군집 평균 계산


  def get_next_point_weight(selected_stone, cluster)

    temp = MAX_NUMBER
    next_point = 0

    cluster.each do |point|
      limit_seta = get_weight_limit_seta(selected_stone, point)
      temp_weight = get_weight_value(selected_stone, point)

      if limit_seta[0] > limit_seta[1]
        if limit_seta[1] < Math.atan2(temp_weight[1],temp_weight[0]) && Math.atan2(temp_weight[1],temp_weight[0]) < limit_seta[0]
          # 각 방향이 충돌 한계 내의 값 일 경우
          if temp > get_length(selected_stone, point)
            # 가장 가까운 돌로 굴절
            temp = get_length(selected_stone, point)
            next_point = temp_weight
          end
        end

      else
        if limit_seta[0] < Math.atan2(temp_weight[1],temp_weight[0]) && Math.atan2(temp_weight[1],temp_weight[0]) < limit_seta[1]
          # 각 방향이 충돌 한계 내의 값 일 경우
          if temp > get_length(selected_stone, point)
            # 가장 가까운 돌로 굴절
            temp = get_length(selected_stone, point)
            next_point = temp_weight
          end
        end
      end

      if next_point == 0
        next_point = [0,0]
      end

    end
    return next_point

  end

  def get_shortest_path(my_stones, your_stones)
    len_temp = MAX_NUMBER
    stone_temp_m = 0
    stone_temp_y = 0

    my_stones.each do |my|
      your_stones.each do |your|
        if get_length(my,your) < len_temp
          len_temp = get_length(my,your)
          stone_temp_m = my
          stone_temp_y = your
        end
      end
    end

    return stone_temp_m, stone_temp_y
  end


  # 벡터 계산
  def get_length(v1, v2)
    x_distance = (v1[0] - v2[0]).abs
    y_distance = (v1[1] - v2[1]).abs

    length = Math.sqrt(x_distance * x_distance + y_distance * y_distance)

    return length
  end

  def get_float(string_temp)
    copy = []
    strings = []

    string_temp.each do |p|
      copy.push p.to_s
    end

    copy.each do |c|
      string = c.delete('[,]').strip.split(" ")
      strings.push string
    end

    floats = []

    strings.each do |string|
      temp = []
      string.each do |s|
        temp.push s.to_f
      end
      floats.push temp
    end
    return floats
  end

end

s.add_handler("alggago", MyAlggago.new)
s.serve
