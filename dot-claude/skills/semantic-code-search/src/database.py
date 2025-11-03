#!/usr/bin/env python3
"""PostgreSQL/pgvector database operations - REUSES existing patterns."""

import os
import sys
from typing import Dict, List, Tuple, Optional, Any
import psycopg2
import psycopg2.extras

class VectorDB:
    """PostgreSQL/pgvector database for semantic code search."""
    
    def __init__(self):
        self.conn = None
        self._connect()
        self._ensure_schema()
    
    def _connect(self):
        """Connect to PostgreSQL using existing patterns."""
        db_url = os.getenv("DATABASE_URL", "postgresql://codesearch:codesearch@postgres:5432/codesearch")
        self.conn = psycopg2.connect(db_url)
        self.conn.autocommit = True
    
    def _ensure_schema(self):
        """Create tables if they don't exist."""
        with self.conn.cursor() as cur:
            # Enable pgvector extension
            cur.execute("CREATE EXTENSION IF NOT EXISTS vector")
            
            # Create table with vector embeddings
            cur.execute("""
                CREATE TABLE IF NOT EXISTS code_elements (
                    id SERIAL PRIMARY KEY,
                    file_path TEXT NOT NULL,
                    element_name TEXT NOT NULL,
                    element_type TEXT NOT NULL,
                    signature TEXT,
                    docstring TEXT,
                    searchable_text TEXT,
                    embedding vector(1536),
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                )
            """)
            
            # Create vector similarity index
            cur.execute("""
                CREATE INDEX IF NOT EXISTS idx_code_elements_embedding 
                ON code_elements USING ivfflat (embedding vector_cosine_ops)
                WITH (lists = 100)
            """)
    
    def clear_all(self):
        """Clear all indexed code elements."""
        with self.conn.cursor() as cur:
            cur.execute("DELETE FROM code_elements")
    
    def insert(self, file_path: str, name: str, element_type: str, 
               signature: str, docstring: str, embedding: List[float]) -> None:
        """Insert code element with embedding vector."""
        from embeddings import create_searchable_text
        
        searchable_text = create_searchable_text(name, signature, docstring)
        
        with self.conn.cursor() as cur:
            cur.execute("""
                INSERT INTO code_elements 
                (file_path, element_name, element_type, signature, docstring, searchable_text, embedding)
                VALUES (%s, %s, %s, %s, %s, %s, %s)
            """, (file_path, name, element_type, signature, docstring, searchable_text, embedding))
    
    def search_similar(self, query_embedding: List[float], limit: int = 5) -> List[Tuple[Dict[str, Any], float]]:
        """Search for similar code elements using vector similarity."""
        with self.conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
            # Use cosine similarity search with pgvector
            cur.execute("""
                SELECT 
                    file_path, element_name, element_type, signature, docstring,
                    1 - (embedding <=> %s::vector) as similarity_score
                FROM code_elements 
                WHERE embedding IS NOT NULL
                ORDER BY embedding <=> %s::vector
                LIMIT %s
            """, (query_embedding, query_embedding, limit))
            
            results = []
            for row in cur.fetchall():
                element = dict(row)
                similarity_score = element.pop('similarity_score')
                results.append((element, float(similarity_score)))
            
            return results
    
    def stats(self) -> Dict[str, int]:
        """Get database statistics."""
        with self.conn.cursor() as cur:
            cur.execute("SELECT COUNT(*) FROM code_elements")
            total = cur.fetchone()[0]
            
            cur.execute("SELECT COUNT(*) FROM code_elements WHERE element_type = 'function'")
            functions = cur.fetchone()[0]
            
            cur.execute("SELECT COUNT(*) FROM code_elements WHERE element_type = 'class'")
            classes = cur.fetchone()[0]
            
            cur.execute("SELECT COUNT(DISTINCT file_path) FROM code_elements")
            files = cur.fetchone()[0]
            
            return {
                'total_elements': total,
                'functions': functions, 
                'classes': classes,
                'unique_files': files
            }
    
    def close(self):
        """Close database connection."""
        if self.conn:
            self.conn.close()