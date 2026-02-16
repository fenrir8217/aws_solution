package com.demo.svcb.controller;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/orders")
public class OrderController {

    @GetMapping
    public List<Map<String, Object>> getOrders() {
        return List.of(
                Map.of("id", 1, "product", "Widget", "quantity", 2, "status", "PENDING"),
                Map.of("id", 2, "product", "Gadget", "quantity", 1, "status", "SHIPPED")
        );
    }
}
