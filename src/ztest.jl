
## Z-test function, thanks to claud
# x1, x2 = successes in each group
# n1, n2 = sample sizes
function twopropztest(x1, n1, x2, n2)
    p1 = x1/n1
    p2 = x2/n2
    p_pooled = (x1 + x2)/(n1 + n2)

    se = sqrt(p_pooled * (1 - p_pooled) * (1/n1 + 1/n2))
    z = (p1 - p2) / se

    # Two-tailed p-value
    p_value = 2 * (1 - cdf(Normal(), abs(z)))

    return p_value
end
