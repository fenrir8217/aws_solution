package com.demo.svcc.controller;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/products")
public class ProductController {

    @GetMapping
    public List<Map<String, Object>> getProducts() {
        return List.of(
                Map.of("id", 1, "name", "Widget", "price", 29.99, "inStock", true),
                Map.of("id", 2, "name", "Gadget", "price", 49.99, "inStock", false)
        );
    }
}
