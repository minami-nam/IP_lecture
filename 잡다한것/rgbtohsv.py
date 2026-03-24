import torch
import torch.nn as nn


def rgb_to_hsv(x_rgb : torch.tensor): 
    r = x_rgb[:, 0:1, :, :]/255
    g = x_rgb[:, 1:2, :, :]/255
    b = x_rgb[:, 2:3, :, :]/255

    cmax = torch.max(r,g,b)
    cmin = torch.min(r,g,b)

    delta = cmax - cmin

    # h
    if cmax==cmin:
        h = 0
    elif cmax==r:
        h = 60 * ((g-b)/delta)
    elif cmax==g:
        h = 60 * (((b-r)/delta)+2)
    elif cmax==b:
        h = 60 * (((r-g)/delta)+4)

    if h<0:
        h = (h + 360)/360
    else:
        h = h/360


    # s
    if cmax==0:
        s = 0
    else:
        s = delta / cmax

    # v
    v = cmax

    hsv = torch.cat((h,s,v), dim=1)

    return hsv

def hsv_to_rgb(x_hsv : torch.tensor):
    h = x_hsv[:, 0:1, :, :]*360
    s = x_hsv[:, 1:2, :, :]
    v = x_hsv[:, 2:3, :, :]

    c = s * v
    mid = c * (1- torch.abs(((h/60)%2)-1))
    m = v - c

    if h>=0 & h<60:
        r = c
        g = mid
        b = 0
    elif h>=60 & h<120:
        r = mid
        g = c
        b = 0
    elif h>=120 & h<180:
        r = 0
        g = c
        b = mid
    elif h>=180 & h<240:
        r = 0
        g = mid
        b = c
    elif h>=240 & h<300:
        r = mid
        g = 0
        b = c
    else:
        r = c
        g = 0
        b = mid

    r = (r + m) * 255
    g = (g + m) * 255
    b = (b + m) * 255

    rgb = torch.cat((r,g,b), dim=1)

    return rgb