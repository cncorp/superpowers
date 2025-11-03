#!/usr/bin/env python3
"""CLI for semantic code search using PostgreSQL/pgvector - FOLLOWS SPEC."""

import sys
import argparse
from typing import Dict, List, Tuple, Any

from indexer import find_python_files, extract_code_elements
from embeddings import generate_embedding, create_searchable_text
from database import VectorDB
import os

def cmd_index(args):
    """Index Python files with vector embeddings."""
    print(f"Indexing Python files in {args.directory}...")
    db = VectorDB()
    
    if args.clear:
        db.clear_all()
        print("Cleared existing index")
    
    python_files = find_python_files(args.directory)
    total_elements = 0
    
    for file_path in python_files:
        print(f"Processing {file_path}...")
        elements = extract_code_elements(file_path)
        
        for element in elements:
            # Create searchable text for embedding
            searchable_text = create_searchable_text(
                element['element_name'], 
                element['signature'], 
                element['docstring']
            )
            
            # Generate vector embedding
            embedding = generate_embedding(searchable_text)
            
            if embedding:
                db.insert(
                    file_path=element['file_path'],
                    name=element['element_name'],
                    element_type=element['element_type'], 
                    signature=element['signature'],
                    docstring=element['docstring'],
                    embedding=embedding
                )
                total_elements += 1
    
    print(f"Indexed {total_elements} elements from {len(python_files)} files")
    db.close()

def cmd_find(args):
    """Find code elements using semantic vector search."""
    db = VectorDB()
    
    # Generate embedding for search query
    query_embedding = generate_embedding(args.query)
    
    if not query_embedding:
        print("Failed to generate embedding for query")
        return
    
    # Perform vector similarity search
    results = db.search_similar(query_embedding, args.limit)
    
    if not results:
        print("No results found")
        db.close()
        return
    
    print(f"\nFound {len(results)} results:")
    print("-" * 80)
    
    for i, (element, score) in enumerate(results, 1):
        print(f"{i}. {element['element_name']} (score: {score:.3f})")
        print(f"   File: {element['file_path']}")
        print(f"   Type: {element['element_type']}")
        print(f"   Signature: {element['signature']}")
        if element['docstring']:
            docstring_preview = element['docstring'][:80]
            if len(element['docstring']) > 80:
                docstring_preview += "..."
            print(f"   Docstring: {docstring_preview}")
        print()
    
    db.close()

def cmd_stats(args):
    """Show indexing statistics."""
    db = VectorDB()
    stats = db.stats()
    
    print("Code Search Statistics:")
    print(f"Total elements: {stats['total_elements']}")
    print(f"Functions: {stats['functions']}")
    print(f"Classes: {stats['classes']}")
    print(f"Files indexed: {stats['unique_files']}")
    
    db.close()

def main():
    """Main CLI entry point."""
    parser = argparse.ArgumentParser(description="Semantic code search tool")
    subparsers = parser.add_subparsers(dest='command')
    
    # Index command
    index_parser = subparsers.add_parser('index', help='Index Python files')
    index_parser.add_argument('directory', help='Directory to index')
    index_parser.add_argument('--clear', action='store_true', help='Clear existing index')
    index_parser.set_defaults(func=cmd_index)
    
    # Find command  
    find_parser = subparsers.add_parser('find', help='Search for code semantically')
    find_parser.add_argument('query', help='Search query')
    find_parser.add_argument('--limit', type=int, default=5, help='Number of results')
    find_parser.set_defaults(func=cmd_find)
    
    # Stats command
    stats_parser = subparsers.add_parser('stats', help='Show statistics')
    stats_parser.set_defaults(func=cmd_stats)
    
    args = parser.parse_args()
    if args.command:
        args.func(args)
    else:
        parser.print_help()

if __name__ == '__main__':
    main()