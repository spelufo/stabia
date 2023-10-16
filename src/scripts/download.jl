include("../data/data.jl")


layer_coverage(layer_jz::Int) = begin
  have = 0
  total = 0
  for r = 1:size(scroll_1_54_mask, 1)
    jy, jx, jz = scroll_1_54_mask[r, :]
    if jz == layer_jz
      total += 1
      if have_grid_cell(scroll_1_54, jy, jx, jz)
        have += 1
      end
    end
  end
  frac = have/total
  println("$have / $total  ($frac)")
  frac, have, total, total - have
end

grid_coverage() = begin
  have = 0
  total = size(scroll_1_54_mask, 1)
  for r = 1:total
    jy, jx, jz = scroll_1_54_mask[r, :]
    if have_grid_cell(scroll_1_54, jy, jx, jz)
      have += 1
    end
  end
  frac = have/total
  println("$have / $total  ($frac)")
  frac, have, total, total - have
end


estimate_layer(layer_jz::Int) = begin
  _, have, total, lack = layer_coverage(layer_jz)
  space_req_gb = round(Int, lack * 244216 / 1024 / 1024)
  time_est = (space_req_gb / 0.030) / 60
  println("space required: $space_req_gb G  ($time_est min @ 30M/s)")
  space_req_gb
end

estimate_required_space_by_layer_gb() =
  [estimate_layer(jz) for jz in 1:29]


download_layer(layer_jz::Int) = begin
  Threads.@threads for thread_jy in 1:ceil(Int, scroll_1_54.height / 500)
    for r = 1:size(scroll_1_54_mask, 1)
      jy, jx, jz = scroll_1_54_mask[r, :]
      if jz == layer_jz && jy == thread_jy
        download_grid_cell(scroll_1_54, jy, jx, jz)
        println("downloaded $jy $jx $jz")
      end
    end
  end
end



#=
julia> for jz = 1:29 println(); println(jz); estimate_layer(jz); end

1
130 / 130  (1.0)
space required: 0 G

2
130 / 130  (1.0)
space required: 0 G

3
4 / 132  (0.030303030303030304)
space required: 30 G

4
13 / 133  (0.09774436090225563)
space required: 28 G

5
10 / 138  (0.07246376811594203)
space required: 30 G

6
0 / 140  (0.0)
space required: 33 G

7
0 / 139  (0.0)
space required: 32 G

8
0 / 131  (0.0)
space required: 31 G

9
0 / 142  (0.0)
space required: 33 G

10
0 / 144  (0.0)
space required: 34 G

11
0 / 139  (0.0)
space required: 32 G

12
0 / 143  (0.0)
space required: 33 G

13
1 / 150  (0.006666666666666667)
space required: 35 G

14
9 / 153  (0.058823529411764705)
space required: 34 G

15
18 / 149  (0.12080536912751678)
space required: 31 G

16
8 / 149  (0.053691275167785234)
space required: 33 G

17
0 / 152  (0.0)
space required: 35 G

18
0 / 148  (0.0)
space required: 34 G

19
0 / 149  (0.0)
space required: 35 G

20
0 / 140  (0.0)
space required: 33 G

21
0 / 137  (0.0)
space required: 32 G

22
52 / 137  (0.3795620437956204)
space required: 20 G

23
46 / 131  (0.3511450381679389)
space required: 20 G

24
16 / 124  (0.12903225806451613)
space required: 25 G

25
0 / 106  (0.0)
space required: 25 G

26
0 / 93  (0.0)
space required: 22 G

27
0 / 72  (0.0)
space required: 17 G

28
0 / 43  (0.0)
space required: 10 G

29
0 / 9  (0.0)
space required: 2 G

=#
