defmodule Calcinator.ControllerTest do
  alias Calcinator.{Authorization.Cant, TestAuthorView, TestPostView}
  alias Calcinator.Resources.{TestAuthor, TestPost, TestTag}
  alias Calcinator.Resources.Ecto.Repo.{Factory, TestAuthors, TestPosts}
  alias Calcinator.Resources.Ecto.Repo.Repo
  alias Plug.Conn

  import Calcinator.Resources.Ecto.Repo.Repo.Case
  import ExUnit.CaptureLog
  import Plug.Conn, only: [put_req_header: 3]
  import Phoenix.ConnTest, only: [build_conn: 0, json_response: 2, response: 2]

  use ExUnit.Case, async: true

  # Callbacks

  setup do
    Application.put_env(:calcinator, TestAuthors, [])

    conn =
      build_conn()
      |> put_req_header("accept", "application/vnd.api+json")
      |> put_req_header("content-type", "application/vnd.api+json")

    [conn: conn]
  end

  # Tests

  doctest Calcinator.Controller

  describe "create/3" do
    test "{:ok, renderer}", %{conn: conn} do
      meta = checkout_meta()

      test_author = %TestAuthor{id: author_id} = Factory.insert(:test_author)
      first_test_tag = %TestTag{id: first_tag_id} = Factory.insert(:test_tag)
      second_test_tag = %TestTag{id: second_tag_id} = Factory.insert(:test_tag)
      body = "First Post!"

      conn =
        Calcinator.Controller.create(
          conn,
          %{
            "meta" => meta,
            "data" => %{
              "type" => "test-posts",
              "attributes" => %{
                "body" => body
              },
              "relationships" => %{
                "author" => %{
                  "data" => %{
                    "type" => "test-authors",
                    "id" => to_string(author_id)
                  }
                },
                # Tests `many_to_many` support for create
                "tags" => %{
                  "data" => [
                    %{
                      "type" => "test-tags",
                      "id" => to_string(first_tag_id)
                    },
                    %{
                      "type" => "test-tags",
                      "id" => to_string(second_tag_id)
                    }
                  ]
                }
              }
            },
            "include" => "author,tags"
          },
          %Calcinator{
            associations_by_include: %{
              "author" => :author,
              "tags" => :tags
            },
            ecto_schema_module: TestPost,
            resources_module: TestPosts,
            view_module: TestPostView
          }
        )

      assert %{
               "data" => %{
                 "type" => "test-posts",
                 "attributes" => %{
                   "body" => ^body
                 }
               },
               "included" => included
             } = json_response(conn, :created)

      included_by_id_by_type = resource_by_id_by_type(included)

      assert included_by_id_by_type["test-authors"][to_string(author_id)] == test_author_resource(test_author)

      test_tags_by_id = included_by_id_by_type["test-tags"]

      assert test_tags_by_id[to_string(first_tag_id)] == test_tag_resource(first_test_tag)
      assert test_tags_by_id[to_string(second_tag_id)] == test_tag_resource(second_test_tag)
    end

    test "{:ok, rendered} with sparse fieldset", %{conn: conn} do
      meta = checkout_meta()

      test_author = %TestAuthor{id: author_id} = Factory.insert(:test_author)
      %TestTag{id: first_tag_id} = Factory.insert(:test_tag)
      %TestTag{id: second_tag_id} = Factory.insert(:test_tag)
      body = "First Post!"

      conn =
        Calcinator.Controller.create(
          conn,
          %{
            "fields" => %{
              # sparse primary to prove it works on create
              "test-posts" => "",
              # sparse only 1 of the included to show sparsing included works, but type targeting works
              "test-tags" => ""
            },
            "meta" => meta,
            "data" => %{
              "type" => "test-posts",
              "attributes" => %{
                "body" => body
              },
              "relationships" => %{
                "author" => %{
                  "data" => %{
                    "type" => "test-authors",
                    "id" => to_string(author_id)
                  }
                },
                # Tests `many_to_many` support for create
                "tags" => %{
                  "data" => [
                    %{
                      "type" => "test-tags",
                      "id" => to_string(first_tag_id)
                    },
                    %{
                      "type" => "test-tags",
                      "id" => to_string(second_tag_id)
                    }
                  ]
                }
              }
            },
            "include" => "author,tags"
          },
          %Calcinator{
            associations_by_include: %{
              "author" => :author,
              "tags" => :tags
            },
            ecto_schema_module: TestPost,
            resources_module: TestPosts,
            view_module: TestPostView
          }
        )

      assert %{
               "data" => %{
                 "type" => "test-posts",
                 "attributes" => attributes
               },
               "included" => included
             } = json_response(conn, :created)

      assert map_size(attributes) == 0

      included_by_id_by_type = resource_by_id_by_type(included)

      assert included_by_id_by_type["test-authors"][to_string(author_id)] == test_author_resource(test_author)

      test_tags_by_id = included_by_id_by_type["test-tags"]

      assert %{"attributes" => first_test_tag_attributes} = test_tags_by_id[to_string(first_tag_id)]
      assert map_size(first_test_tag_attributes) == 0

      assert %{"attributes" => second_test_tag_attributes} = test_tags_by_id[to_string(second_tag_id)]
      assert map_size(second_test_tag_attributes) == 0
    end

    test "{:error, :sandbox_access_disallowed}", %{conn: conn} do
      meta = checkout_meta()
      Ecto.Adapters.SQL.Sandbox.checkin(Repo)

      conn =
        Calcinator.Controller.create(
          conn,
          %{
            "data" => %{
              "type" => "test-authors",
              "attributes" => %{
                "name" => "Alice"
              }
            },
            "meta" => meta
          },
          %Calcinator{ecto_schema_module: TestAuthor, resources_module: TestAuthors, view_module: TestAuthorView}
        )

      assert_sandox_access_disallowed(conn)
    end

    test "{:error, :sandbox_token_missing}", %{conn: conn} do
      conn =
        Calcinator.Controller.create(
          conn,
          %{
            "data" => %{
              "type" => "test-authors",
              "attributes" => %{
                "name" => "Alice"
              }
            }
          },
          %Calcinator{ecto_schema_module: TestAuthor, resources_module: TestAuthors, view_module: TestAuthorView}
        )

      assert_sandbox_token_missing(conn)
    end

    test "{:error, :timeout}", %{conn: conn} do
      Application.put_env(:calcinator, TestAuthors, insert: {:error, :timeout})

      conn =
        Calcinator.Controller.create(
          conn,
          %{
            "data" => %{
              "type" => "test-authors",
              "attributes" => %{
                "name" => "Alice"
              }
            },
            "meta" => checkout_meta()
          },
          %Calcinator{ecto_schema_module: TestAuthor, resources_module: TestAuthors, view_module: TestAuthorView}
        )

      assert_timeout(conn)
    end

    test "{:error, :unauthorized}", %{conn: conn} do
      conn =
        Calcinator.Controller.create(
          conn,
          %{
            "data" => %{
              "type" => "test-authors",
              "attributes" => %{
                "name" => "Alice"
              }
            },
            "meta" => checkout_meta()
          },
          %Calcinator{
            authorization_module: Cant,
            ecto_schema_module: TestAuthor,
            resources_module: TestAuthors,
            view_module: TestAuthorView
          }
        )

      assert_unauthorized(conn)
    end

    test "{:error, Alembic.Document.t}", %{conn: conn} do
      conn =
        Calcinator.Controller.create(
          conn,
          %{
            "data" => %{},
            "meta" => checkout_meta()
          },
          %Calcinator{ecto_schema_module: TestAuthor, resources_module: TestAuthors, view_module: TestAuthorView}
        )

      assert %{"errors" => errors} = json_response(conn, 422)
      assert length(errors) == 2

      assert %{
               "detail" => "`/data/type` is missing",
               "meta" => %{
                 "child" => "type"
               },
               "source" => %{
                 "pointer" => "/data"
               },
               "status" => "422",
               "title" => "Child missing"
             } in errors

      assert %{
               "detail" => "`/data/id` is missing",
               "meta" => %{
                 "child" => "id"
               },
               "source" => %{
                 "pointer" => "/data"
               },
               "status" => "422",
               "title" => "Child missing"
             } in errors
    end

    test "{:error, Ecto.Changeset.t}", %{conn: conn} do
      conn =
        Calcinator.Controller.create(
          conn,
          %{
            "data" => %{
              "type" => "test-authors",
              "attributes" => %{}
            },
            "meta" => checkout_meta()
          },
          %Calcinator{ecto_schema_module: TestAuthor, resources_module: TestAuthors, view_module: TestAuthorView}
        )

      assert %{"errors" => errors} = json_response(conn, 422)
      assert length(errors) == 1

      assert %{
               "detail" => "name can't be blank",
               "source" => %{
                 "pointer" => "/data/attributes/name"
               },
               "title" => "can't be blank"
             } in errors
    end

    test "{:error, Ecto.Changeset.t} when many_to_many ID does not exist", %{conn: conn} do
      meta = checkout_meta()

      %TestAuthor{id: author_id} = Factory.insert(:test_author)
      body = "First Post!"

      conn =
        Calcinator.Controller.create(
          conn,
          %{
            "meta" => meta,
            "data" => %{
              "type" => "test-posts",
              "attributes" => %{
                "body" => body
              },
              "relationships" => %{
                "author" => %{
                  "data" => %{
                    "type" => "test-authors",
                    "id" => to_string(author_id)
                  }
                },
                # Tests `many_to_many` support for create
                "tags" => %{
                  "data" => [
                    %{
                      "type" => "test-tags",
                      "id" => to_string(-1)
                    }
                  ]
                }
              }
            },
            "include" => "author,tags"
          },
          %Calcinator{
            associations_by_include: %{
              "author" => :author,
              "tags" => :tags
            },
            ecto_schema_module: TestPost,
            resources_module: TestPosts,
            view_module: TestPostView
          }
        )

      assert %{"errors" => errors} = json_response(conn, 422)

      assert is_list(errors)
      assert length(errors) == 1

      assert %{
               "detail" => "tags has element at index 0 whose id (-1) does not exist",
               "source" => %{
                 "pointer" => "/data/relationships/tags"
               },
               "title" => "has element at index 0 whose id (-1) does not exist"
             } in errors
    end
  end

  describe "delete/3" do
    test ":ok", %{conn: conn} do
      meta = checkout_meta()
      %TestAuthor{id: id} = Factory.insert(:test_author)

      conn =
        Calcinator.Controller.delete(
          conn,
          %{
            "id" => id,
            "meta" => meta
          },
          %Calcinator{ecto_schema_module: TestAuthor, resources_module: TestAuthors, view_module: TestAuthorView}
        )

      assert response(conn, :no_content) == ""
    end

    test "{:error, {:not_found, _}}", %{conn: conn} do
      conn =
        Calcinator.Controller.delete(
          conn,
          %{
            "id" => -1,
            "meta" => checkout_meta()
          },
          %Calcinator{ecto_schema_module: TestAuthor, resources_module: TestAuthors, view_module: TestAuthorView}
        )

      assert_not_found(conn, "id")
    end

    test "{:error, :sandbox_access_disallowed}", %{conn: conn} do
      meta = checkout_meta()
      %TestAuthor{id: id} = Factory.insert(:test_author)
      Ecto.Adapters.SQL.Sandbox.checkin(Repo)

      conn =
        Calcinator.Controller.delete(
          conn,
          %{
            "id" => id,
            "meta" => meta
          },
          %Calcinator{ecto_schema_module: TestAuthor, resources_module: TestAuthors, view_module: TestAuthorView}
        )

      assert_sandox_access_disallowed(conn)
    end

    test "{:error, :sandbox_token_missing}", %{conn: conn} do
      :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
      %TestAuthor{id: id} = Factory.insert(:test_author)

      conn =
        Calcinator.Controller.delete(
          conn,
          %{
            "id" => id
          },
          %Calcinator{ecto_schema_module: TestAuthor, resources_module: TestAuthors, view_module: TestAuthorView}
        )

      assert_sandbox_token_missing(conn)
    end

    test "{:error, :timeout} from Calcinator.Resources.get/2", %{conn: conn} do
      Application.put_env(:calcinator, TestAuthors, get: {:error, :timeout})

      meta = checkout_meta()
      %TestAuthor{id: id} = Factory.insert(:test_author)

      conn =
        Calcinator.Controller.delete(
          conn,
          %{
            "id" => id,
            "meta" => meta
          },
          %Calcinator{ecto_schema_module: TestAuthor, resources_module: TestAuthors, view_module: TestAuthorView}
        )

      assert_timeout(conn)
    end

    test "{:error, :timeout} from Calcinator.Resources.delete/1", %{conn: conn} do
      Application.put_env(:calcinator, TestAuthors, delete: {:error, :timeout})

      meta = checkout_meta()
      %TestAuthor{id: id} = Factory.insert(:test_author)

      conn =
        Calcinator.Controller.delete(
          conn,
          %{
            "id" => id,
            "meta" => meta
          },
          %Calcinator{ecto_schema_module: TestAuthor, resources_module: TestAuthors, view_module: TestAuthorView}
        )

      assert_timeout(conn)
    end

    test "{:error, :unauthorized}", %{conn: conn} do
      meta = checkout_meta()
      %TestAuthor{id: id} = Factory.insert(:test_author)

      conn =
        Calcinator.Controller.delete(
          conn,
          %{
            "id" => id,
            "meta" => meta
          },
          %Calcinator{
            authorization_module: Cant,
            ecto_schema_module: TestAuthor,
            resources_module: TestAuthors,
            view_module: TestAuthorView
          }
        )

      assert_unauthorized(conn)
    end

    test "{:error, Alembic.Document.t}", %{conn: conn} do
      meta = checkout_meta()
      %TestAuthor{id: id} = Factory.insert(:test_author)

      conn =
        Calcinator.Controller.delete(
          conn,
          %{
            "id" => id,
            "include" => "post",
            "meta" => meta
          },
          %Calcinator{ecto_schema_module: TestAuthor, resources_module: TestAuthors, view_module: TestAuthorView}
        )

      assert %{"errors" => errors} = json_response(conn, 422)
      assert length(errors) == 1

      assert %{
               "detail" => "`post` is an unknown relationship path",
               "meta" => %{
                 "relationship_path" => "post"
               },
               "source" => %{
                 "parameter" => "include"
               },
               "title" => "Unknown relationship path"
             } in errors
    end

    test "{:error, Ecto.Changeset.t}", %{conn: conn} do
      meta = checkout_meta()
      author = %TestAuthor{id: id} = Factory.insert(:test_author)
      Factory.insert(:test_post, author: author)

      conn =
        Calcinator.Controller.delete(
          conn,
          %{
            "id" => id,
            "meta" => meta
          },
          %Calcinator{ecto_schema_module: TestAuthor, resources_module: TestAuthors, view_module: TestAuthorView}
        )

      assert %{"errors" => errors} = json_response(conn, 422)
      assert length(errors) == 1

      assert %{
               "detail" => "posts are still associated with this entry",
               "source" => %{
                 "pointer" => "/data/relationships/posts"
               },
               "title" => "are still associated with this entry"
             } in errors
    end

    test "{:error, reason}", %{conn: conn} do
      meta = checkout_meta()
      %TestAuthor{id: id} = Factory.insert(:test_author)

      assert_error_reason(:delete, fn ->
        Calcinator.Controller.delete(
          conn,
          %{
            "id" => id,
            "meta" => meta
          },
          %Calcinator{ecto_schema_module: TestAuthor, resources_module: TestAuthors, view_module: TestAuthorView}
        )
      end)
    end
  end

  describe "get_related_resource/3" do
    test "{:ok, rendered} for belongs_to", %{conn: conn} do
      meta = checkout_meta()
      %TestPost{author: author = %TestAuthor{}, id: id} = Factory.insert(:test_post)

      # done by route.ex definition of route
      conn = Conn.assign(conn, :related, %{view_module: TestAuthorView})
      conn = Conn.assign(conn, :source, %{association: :author, id_key: "post_id"})

      # route like `/posts/:post_id/author`
      conn =
        Calcinator.Controller.get_related_resource(
          conn,
          %{
            "post_id" => id,
            "meta" => meta
          },
          %Calcinator{ecto_schema_module: TestPost, resources_module: TestPosts, view_module: TestPostView}
        )

      assert json_response(conn, :ok) ==
               %{
                 "jsonapi" => %{
                   "version" => "1.0"
                 },
                 "data" => %{
                   "type" => "test-authors",
                   "id" => to_string(author.id),
                   "attributes" => %{
                     "name" => author.name
                   },
                   "links" => %{
                     "self" => "/api/v1/test-posts/#{id}/author"
                   },
                   "relationships" => %{
                     "posts" => %{}
                   }
                 }
               }
    end

    test "{:ok, rendered} for belongs_to with sparse fieldset", %{conn: conn} do
      meta = checkout_meta()
      %TestPost{author: author = %TestAuthor{}, id: id} = Factory.insert(:test_post)

      # done by route.ex definition of route
      conn = Conn.assign(conn, :related, %{view_module: TestAuthorView})
      conn = Conn.assign(conn, :source, %{association: :author, id_key: "post_id"})

      # route like `/posts/:post_id/author`
      conn =
        Calcinator.Controller.get_related_resource(
          conn,
          %{
            "post_id" => id,
            # turn off all attributes since there's only one
            "fields" => %{"test-authors" => ""},
            "meta" => meta
          },
          %Calcinator{ecto_schema_module: TestPost, resources_module: TestPosts, view_module: TestPostView}
        )

      assert json_response(conn, :ok) ==
               %{
                 "jsonapi" => %{
                   "version" => "1.0"
                 },
                 "data" => %{
                   "type" => "test-authors",
                   "id" => to_string(author.id),
                   "attributes" => %{},
                   "links" => %{
                     "self" => "/api/v1/test-posts/#{id}/author"
                   },
                   "relationships" => %{
                     "posts" => %{}
                   }
                 }
               }
    end

    test "{:ok, rendered} for has_many", %{conn: conn} do
      meta = checkout_meta()

      post =
        %TestPost{
          author: %TestAuthor{
            id: author_id
          }
        } = Factory.insert(:test_post)

      # done by route.ex definition of route
      conn = Conn.assign(conn, :related, %{view_module: TestPostView})
      conn = Conn.assign(conn, :source, %{association: :posts, id_key: "author_id"})

      # route like `/authors/:author_id/posts`
      conn =
        Calcinator.Controller.get_related_resource(
          conn,
          %{
            "author_id" => author_id,
            "meta" => meta
          },
          %Calcinator{ecto_schema_module: TestAuthor, resources_module: TestAuthors, view_module: TestAuthorView}
        )

      assert %{"data" => data, "links" => links} = json_response(conn, :ok)

      assert is_list(data)
      assert length(data) == 1

      assert %{
               "type" => "test-posts",
               "id" => to_string(post.id),
               "attributes" => %{
                 "body" => post.body
               },
               "links" => %{
                 "self" => "/api/v1/test-posts/#{post.id}"
               },
               "relationships" => %{
                 "tags" => %{}
               }
             } in data

      assert links == %{"self" => "/api/v1/test-authors/#{author_id}/posts"}
    end

    test "{:ok, rendered} for has_many with sparse fieldsets", %{conn: conn} do
      meta = checkout_meta()

      post =
        %TestPost{
          author: %TestAuthor{
            id: author_id
          }
        } = Factory.insert(:test_post)

      # done by route.ex definition of route
      conn = Conn.assign(conn, :related, %{view_module: TestPostView})
      conn = Conn.assign(conn, :source, %{association: :posts, id_key: "author_id"})

      # route like `/authors/:author_id/posts`
      conn =
        Calcinator.Controller.get_related_resource(
          conn,
          %{
            "author_id" => author_id,
            "fields" => %{"test-posts" => ""},
            "meta" => meta
          },
          %Calcinator{ecto_schema_module: TestAuthor, resources_module: TestAuthors, view_module: TestAuthorView}
        )

      assert %{"data" => data, "links" => links} = json_response(conn, :ok)

      assert is_list(data)
      assert length(data) == 1

      assert %{
               "type" => "test-posts",
               "id" => to_string(post.id),
               "attributes" => %{},
               "links" => %{
                 "self" => "/api/v1/test-posts/#{post.id}"
               },
               "relationships" => %{
                 "tags" => %{}
               }
             } in data

      assert links == %{"self" => "/api/v1/test-authors/#{author_id}/posts"}
    end

    test "{:error, {:not_found, _}}", %{conn: conn} do
      meta = checkout_meta()

      # done by route.ex definition of route
      conn = Conn.assign(conn, :related, %{view_module: TestAuthorView})
      conn = Conn.assign(conn, :source, %{association: :author, id_key: "post_id"})

      # route like `/posts/:post_id/author`
      conn =
        Calcinator.Controller.get_related_resource(
          conn,
          %{
            "post_id" => -1,
            "meta" => meta
          },
          %Calcinator{ecto_schema_module: TestPost, resources_module: TestPosts, view_module: TestPostView}
        )

      assert_not_found(conn, "post_id")
    end

    test "{:error, :sandbox_access_disallowed}", %{conn: conn} do
      meta = checkout_meta()
      %TestPost{author: %TestAuthor{}, id: id} = Factory.insert(:test_post)
      Ecto.Adapters.SQL.Sandbox.checkin(Repo)

      # done by route.ex definition of route
      conn = Conn.assign(conn, :related, %{view_module: TestAuthorView})
      conn = Conn.assign(conn, :source, %{association: :author, id_key: "post_id"})

      # route like `/posts/:post_id/author`
      conn =
        Calcinator.Controller.get_related_resource(
          conn,
          %{
            "post_id" => id,
            "meta" => meta
          },
          %Calcinator{ecto_schema_module: TestPost, resources_module: TestPosts, view_module: TestPostView}
        )

      assert_sandox_access_disallowed(conn)
    end

    test "{:error, :sandbox_token_missing}", %{conn: conn} do
      :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
      %TestPost{author: %TestAuthor{}, id: id} = Factory.insert(:test_post)

      # done by route.ex definition of route
      conn = Conn.assign(conn, :related, %{view_module: TestAuthorView})
      conn = Conn.assign(conn, :source, %{association: :author, id_key: "post_id"})

      # route like `/posts/:post_id/author`
      conn =
        Calcinator.Controller.get_related_resource(
          conn,
          %{
            "post_id" => id
          },
          %Calcinator{ecto_schema_module: TestPost, resources_module: TestPosts, view_module: TestPostView}
        )

      assert_sandbox_token_missing(conn)
    end

    test "{:error, :timeout}", %{conn: conn} do
      Application.put_env(:calcinator, TestAuthors, get: {:error, :timeout})

      meta = checkout_meta()

      %TestPost{
        author: %TestAuthor{
          id: author_id
        }
      } = Factory.insert(:test_post)

      # done by route.ex definition of route
      conn = Conn.assign(conn, :related, %{view_module: TestPostView})
      conn = Conn.assign(conn, :source, %{association: :posts, id_key: "author_id"})

      # route like `/authors/:author_id/posts`
      conn =
        Calcinator.Controller.get_related_resource(
          conn,
          %{
            "author_id" => author_id,
            "meta" => meta
          },
          %Calcinator{ecto_schema_module: TestAuthor, resources_module: TestAuthors, view_module: TestAuthorView}
        )

      assert_timeout(conn)
    end

    test "{:error, :unauthorized}", %{conn: conn} do
      meta = checkout_meta()
      %TestPost{author: %TestAuthor{}, id: id} = Factory.insert(:test_post)

      # done by route.ex definition of route
      conn = Conn.assign(conn, :related, %{view_module: TestAuthorView})
      conn = Conn.assign(conn, :source, %{association: :author, id_key: "post_id"})

      # route like `/posts/:post_id/author`
      conn =
        Calcinator.Controller.get_related_resource(
          conn,
          %{
            "post_id" => id,
            "meta" => meta
          },
          %Calcinator{
            authorization_module: Cant,
            ecto_schema_module: TestPost,
            resources_module: TestPosts,
            view_module: TestPostView
          }
        )

      assert_unauthorized(conn)
    end

    test "{:error, reason}", %{conn: conn} do
      meta = checkout_meta()

      %TestPost{
        author: %TestAuthor{
          id: author_id
        }
      } = Factory.insert(:test_post)

      # done by route.ex definition of route
      conn = Conn.assign(conn, :related, %{view_module: TestPostView})
      conn = Conn.assign(conn, :source, %{association: :posts, id_key: "author_id"})

      assert_error_reason(:get, fn ->
        Calcinator.Controller.get_related_resource(
          conn,
          %{
            "author_id" => author_id,
            "meta" => meta
          },
          %Calcinator{ecto_schema_module: TestAuthor, resources_module: TestAuthors, view_module: TestAuthorView}
        )
      end)
    end
  end

  describe "index/3" do
    test "{:ok, rendered}", %{conn: conn} do
      meta = checkout_meta()
      count = 2
      test_authors = Factory.insert_list(count, :test_author)

      conn =
        Calcinator.Controller.index(
          conn,
          %{
            "meta" => meta
          },
          %Calcinator{ecto_schema_module: TestAuthor, resources_module: TestAuthors, view_module: TestAuthorView}
        )

      assert %{"data" => data} = json_response(conn, :ok)
      assert is_list(data)
      assert length(data) == count

      Enum.each(test_authors, fn test_author ->
        assert test_author_resource(test_author) in data
      end)
    end

    test "{:ok, rendered} with sparse fieldset", %{conn: conn} do
      meta = checkout_meta()
      Factory.insert(:test_author)

      conn =
        Calcinator.Controller.index(
          conn,
          %{
            # turn off all attributes since there's only one
            "fields" => %{"test-authors" => ""},
            "meta" => meta
          },
          %Calcinator{ecto_schema_module: TestAuthor, resources_module: TestAuthors, view_module: TestAuthorView}
        )

      assert %{"data" => [%{"attributes" => attributes}]} = json_response(conn, :ok)
      assert map_size(attributes) == 0
    end

    test "{:error, :sandbox_access_disallowed}", %{conn: conn} do
      meta = checkout_meta()
      count = 2
      Factory.insert_list(count, :test_author)
      Ecto.Adapters.SQL.Sandbox.checkin(Repo)

      conn =
        Calcinator.Controller.index(
          conn,
          %{
            "meta" => meta
          },
          %Calcinator{ecto_schema_module: TestAuthor, resources_module: TestAuthors, view_module: TestAuthorView}
        )

      assert_sandox_access_disallowed(conn)
    end

    test "{:error, :sandbox_token_missing}", %{conn: conn} do
      :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
      count = 2
      Factory.insert_list(count, :test_author)

      conn =
        Calcinator.Controller.index(conn, %{}, %Calcinator{
          ecto_schema_module: TestAuthor,
          resources_module: TestAuthors,
          view_module: TestAuthorView
        })

      assert_sandbox_token_missing(conn)
    end

    test "{:error, :timeout}", %{conn: conn} do
      Application.put_env(:calcinator, TestAuthors, list: {:error, :timeout})
      meta = checkout_meta()
      count = 2
      Factory.insert_list(count, :test_author)

      conn =
        Calcinator.Controller.index(
          conn,
          %{
            "meta" => meta
          },
          %Calcinator{ecto_schema_module: TestAuthor, resources_module: TestAuthors, view_module: TestAuthorView}
        )

      assert_timeout(conn)
    end

    test "{:error, $Alembic.Document{}}", %{conn: conn} do
      bad_request_error = %Alembic.Error{
        detail: "Description",
        status: "400",
        title: "Bad Request"
      }

      error_on_update = {:error, %Alembic.Document{errors: [bad_request_error]}}

      Application.put_env(:calcinator, TestAuthors, update: error_on_update)

      meta = checkout_meta()
      %TestAuthor{id: id} = Factory.insert(:test_author, name: "Alice")

      conn =
        Calcinator.Controller.update(
          conn,
          %{
            "id" => id,
            "data" => %{
              "type" => "test-authors",
              "id" => to_string(id),
              "attributes" => %{
                "name" => "Eve"
              }
            },
            "meta" => meta
          },
          %Calcinator{ecto_schema_module: TestAuthor, resources_module: TestAuthors, view_module: TestAuthorView}
        )

      assert %{"errors" => errors} = json_response(conn, :bad_request)
      assert is_list(errors)
      assert length(errors) == 1

      assert %{
               "detail" => "Description",
               "status" => "400",
               "title" => "Bad Request"
             } in errors
    end

    test "{:error, :unauthorized}", %{conn: conn} do
      meta = checkout_meta()
      count = 2
      Factory.insert_list(count, :test_author)

      conn =
        Calcinator.Controller.index(
          conn,
          %{
            "meta" => meta
          },
          %Calcinator{
            authorization_module: Cant,
            ecto_schema_module: TestAuthor,
            resources_module: TestAuthors,
            view_module: TestAuthorView
          }
        )

      assert_unauthorized(conn)
    end

    test "{:error, Alembic.Document.t}", %{conn: conn} do
      meta = checkout_meta()
      count = 2
      Factory.insert_list(count, :test_author)

      conn =
        Calcinator.Controller.index(
          conn,
          %{
            "include" => "post",
            "meta" => meta
          },
          %Calcinator{ecto_schema_module: TestAuthor, resources_module: TestAuthors, view_module: TestAuthorView}
        )

      assert %{"errors" => errors} = json_response(conn, 422)
      assert length(errors) == 1

      assert %{
               "detail" => "`post` is an unknown relationship path",
               "meta" => %{
                 "relationship_path" => "post"
               },
               "source" => %{
                 "parameter" => "include"
               },
               "title" => "Unknown relationship path"
             } in errors
    end
  end

  describe "show/3" do
    test "{:ok, rendered}", %{conn: conn} do
      meta = checkout_meta()
      test_author = Factory.insert(:test_author)

      conn =
        Calcinator.Controller.show(
          conn,
          %{
            "id" => test_author.id,
            "meta" => meta
          },
          %Calcinator{ecto_schema_module: TestAuthor, resources_module: TestAuthors, view_module: TestAuthorView}
        )

      assert %{"data" => data} = json_response(conn, :ok)
      assert data == test_author_resource(test_author)
    end

    test "{:ok, rendered} with sparse fieldsets", %{conn: conn} do
      meta = checkout_meta()
      test_author = Factory.insert(:test_author)

      conn =
        Calcinator.Controller.show(
          conn,
          %{
            # turn off all attributes since there's only one
            "fields" => %{"test-authors" => ""},
            "id" => test_author.id,
            "meta" => meta
          },
          %Calcinator{ecto_schema_module: TestAuthor, resources_module: TestAuthors, view_module: TestAuthorView}
        )

      assert %{"data" => %{"attributes" => attributes}} = json_response(conn, :ok)
      assert map_size(attributes) == 0
    end

    test "{:error, {:not_found, _}}", %{conn: conn} do
      meta = checkout_meta()

      conn =
        Calcinator.Controller.show(
          conn,
          %{
            "id" => -1,
            "meta" => meta
          },
          %Calcinator{ecto_schema_module: TestAuthor, resources_module: TestAuthors, view_module: TestAuthorView}
        )

      assert_not_found(conn, "id")
    end

    test "{:error, :sandbox_access_disallowed}", %{conn: conn} do
      meta = checkout_meta()
      %TestAuthor{id: id} = Factory.insert(:test_author)
      Ecto.Adapters.SQL.Sandbox.checkin(Repo)

      conn =
        Calcinator.Controller.show(
          conn,
          %{
            "id" => id,
            "meta" => meta
          },
          %Calcinator{ecto_schema_module: TestAuthor, resources_module: TestAuthors, view_module: TestAuthorView}
        )

      assert_sandox_access_disallowed(conn)
    end

    test "{:error, :sandbox_token_missing}", %{conn: conn} do
      :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
      %TestAuthor{id: id} = Factory.insert(:test_author)

      conn =
        Calcinator.Controller.show(
          conn,
          %{
            "id" => id
          },
          %Calcinator{ecto_schema_module: TestAuthor, resources_module: TestAuthors, view_module: TestAuthorView}
        )

      assert_sandbox_token_missing(conn)
    end

    test "{:error, :timeout}", %{conn: conn} do
      Application.put_env(:calcinator, TestAuthors, get: {:error, :timeout})
      meta = checkout_meta()
      %TestAuthor{id: id} = Factory.insert(:test_author)

      conn =
        Calcinator.Controller.show(
          conn,
          %{
            "id" => id,
            "meta" => meta
          },
          %Calcinator{ecto_schema_module: TestAuthor, resources_module: TestAuthors, view_module: TestAuthorView}
        )

      assert_timeout(conn)
    end

    test "{:error, :unauthorized}", %{conn: conn} do
      meta = checkout_meta()
      %TestAuthor{id: id} = Factory.insert(:test_author)

      conn =
        Calcinator.Controller.show(
          conn,
          %{
            "id" => id,
            "meta" => meta
          },
          %Calcinator{
            authorization_module: Cant,
            ecto_schema_module: TestAuthor,
            resources_module: TestAuthors,
            view_module: TestAuthorView
          }
        )

      assert_unauthorized(conn)
    end

    test "{:error, Alembic.Document.t}", %{conn: conn} do
      meta = checkout_meta()
      %TestAuthor{id: id} = Factory.insert(:test_author)

      conn =
        Calcinator.Controller.show(
          conn,
          %{
            "id" => id,
            "include" => "post",
            "meta" => meta
          },
          %Calcinator{ecto_schema_module: TestAuthor, resources_module: TestAuthors, view_module: TestAuthorView}
        )

      assert %{"errors" => errors} = json_response(conn, 422)
      assert length(errors) == 1

      assert %{
               "detail" => "`post` is an unknown relationship path",
               "meta" => %{
                 "relationship_path" => "post"
               },
               "source" => %{
                 "parameter" => "include"
               },
               "title" => "Unknown relationship path"
             } in errors
    end

    test "{:error, reason}", %{conn: conn} do
      meta = checkout_meta()
      %TestAuthor{id: id} = Factory.insert(:test_author)

      assert_error_reason(:get, fn ->
        Calcinator.Controller.show(
          conn,
          %{
            "id" => id,
            "meta" => meta
          },
          %Calcinator{ecto_schema_module: TestAuthor, resources_module: TestAuthors, view_module: TestAuthorView}
        )
      end)
    end
  end

  describe "show_relationship/3" do
    test "{:ok, rendered} for belongs_to", %{conn: conn} do
      meta = checkout_meta()
      %TestPost{author: author = %TestAuthor{}, id: id} = Factory.insert(:test_post)

      # done by route.ex definition of route
      conn = Conn.assign(conn, :related, %{view_module: TestAuthorView})
      conn = Conn.assign(conn, :source, %{association: :author, id_key: "post_id"})

      # route like `/posts/:post_id/relationship/author`
      conn =
        Calcinator.Controller.show_relationship(
          conn,
          %{
            "post_id" => id,
            "meta" => meta
          },
          %Calcinator{ecto_schema_module: TestPost, resources_module: TestPosts, view_module: TestPostView}
        )

      assert json_response(conn, :ok) ==
               %{
                 "jsonapi" => %{
                   "version" => "1.0"
                 },
                 "data" => %{
                   "id" => to_string(author.id),
                   "type" => "test-authors"
                 },
                 "links" => %{
                   "related" => "/api/v1/test-posts/#{id}/author",
                   "self" => "/api/v1/test-posts/#{id}/relationships/author"
                 }
               }
    end

    test "{:ok, rendered} for has_many", %{conn: conn} do
      meta = checkout_meta()

      post =
        %TestPost{
          author: %TestAuthor{
            id: author_id
          }
        } = Factory.insert(:test_post)

      # done by route.ex definition of route
      conn = Conn.assign(conn, :related, %{view_module: TestPostView})
      conn = Conn.assign(conn, :source, %{association: :posts, id_key: "author_id"})

      # route like `/authors/:author_id/posts`
      conn =
        Calcinator.Controller.show_relationship(
          conn,
          %{
            "author_id" => author_id,
            "meta" => meta
          },
          %Calcinator{ecto_schema_module: TestAuthor, resources_module: TestAuthors, view_module: TestAuthorView}
        )

      assert %{"data" => data, "links" => links} = json_response(conn, :ok)

      assert is_list(data)
      assert length(data) == 1

      assert %{
               "type" => "test-posts",
               "id" => to_string(post.id)
             } in data

      assert links == %{
               "related" => "/api/v1/test-authors/#{author_id}/posts",
               "self" => "/api/v1/test-authors/#{author_id}/relationships/posts"
             }
    end

    test "{:error, {:not_found, _}}", %{conn: conn} do
      meta = checkout_meta()

      # done by route.ex definition of route
      conn = Conn.assign(conn, :related, %{view_module: TestAuthorView})
      conn = Conn.assign(conn, :source, %{association: :author, id_key: "post_id"})

      # route like `/posts/:post_id/author`
      conn =
        Calcinator.Controller.show_relationship(
          conn,
          %{
            "post_id" => -1,
            "meta" => meta
          },
          %Calcinator{ecto_schema_module: TestPost, resources_module: TestPosts, view_module: TestPostView}
        )

      assert_not_found(conn, "post_id")
    end

    test "{:error, :sandbox_access_disallowed}", %{conn: conn} do
      meta = checkout_meta()
      %TestPost{author: %TestAuthor{}, id: id} = Factory.insert(:test_post)
      Ecto.Adapters.SQL.Sandbox.checkin(Repo)

      # done by route.ex definition of route
      conn = Conn.assign(conn, :related, %{view_module: TestAuthorView})
      conn = Conn.assign(conn, :source, %{association: :author, id_key: "post_id"})

      # route like `/posts/:post_id/author`
      conn =
        Calcinator.Controller.show_relationship(
          conn,
          %{
            "post_id" => id,
            "meta" => meta
          },
          %Calcinator{ecto_schema_module: TestPost, resources_module: TestPosts, view_module: TestPostView}
        )

      assert_sandox_access_disallowed(conn)
    end

    test "{:error, :sandbox_token_missing}", %{conn: conn} do
      :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
      %TestPost{author: %TestAuthor{}, id: id} = Factory.insert(:test_post)

      # done by route.ex definition of route
      conn = Conn.assign(conn, :related, %{view_module: TestAuthorView})
      conn = Conn.assign(conn, :source, %{association: :author, id_key: "post_id"})

      # route like `/posts/:post_id/author`
      conn =
        Calcinator.Controller.show_relationship(
          conn,
          %{
            "post_id" => id
          },
          %Calcinator{ecto_schema_module: TestPost, resources_module: TestPosts, view_module: TestPostView}
        )

      assert_sandbox_token_missing(conn)
    end

    test "{:error, :timeout}", %{conn: conn} do
      Application.put_env(:calcinator, TestAuthors, get: {:error, :timeout})

      meta = checkout_meta()

      %TestPost{
        author: %TestAuthor{
          id: author_id
        }
      } = Factory.insert(:test_post)

      # done by route.ex definition of route
      conn = Conn.assign(conn, :related, %{view_module: TestPostView})
      conn = Conn.assign(conn, :source, %{association: :posts, id_key: "author_id"})

      # route like `/authors/:author_id/posts`
      conn =
        Calcinator.Controller.show_relationship(
          conn,
          %{
            "author_id" => author_id,
            "meta" => meta
          },
          %Calcinator{ecto_schema_module: TestAuthor, resources_module: TestAuthors, view_module: TestAuthorView}
        )

      assert_timeout(conn)
    end

    test "{:error, :unauthorized}", %{conn: conn} do
      meta = checkout_meta()
      %TestPost{author: %TestAuthor{}, id: id} = Factory.insert(:test_post)

      # done by route.ex definition of route
      conn = Conn.assign(conn, :related, %{view_module: TestAuthorView})
      conn = Conn.assign(conn, :source, %{association: :author, id_key: "post_id"})

      # route like `/posts/:post_id/author`
      conn =
        Calcinator.Controller.show_relationship(
          conn,
          %{
            "post_id" => id,
            "meta" => meta
          },
          %Calcinator{
            authorization_module: Cant,
            ecto_schema_module: TestPost,
            resources_module: TestPosts,
            view_module: TestPostView
          }
        )

      assert_unauthorized(conn)
    end

    test "{:error, reason}", %{conn: conn} do
      meta = checkout_meta()

      %TestPost{
        author: %TestAuthor{
          id: author_id
        }
      } = Factory.insert(:test_post)

      # done by route.ex definition of route
      conn = Conn.assign(conn, :related, %{view_module: TestPostView})
      conn = Conn.assign(conn, :source, %{association: :posts, id_key: "author_id"})

      assert_error_reason(:get, fn ->
        Calcinator.Controller.show_relationship(
          conn,
          %{
            "author_id" => author_id,
            "meta" => meta
          },
          %Calcinator{ecto_schema_module: TestAuthor, resources_module: TestAuthors, view_module: TestAuthorView}
        )
      end)
    end
  end

  describe "update/3" do
    test "{:ok, rendered}", %{conn: conn} do
      meta = checkout_meta()
      test_tag = Factory.insert(:test_tag)
      %TestPost{id: id} = Factory.insert(:test_post, tags: [test_tag])
      updated_body = "Updated Body"
      updated_test_tag = Factory.insert(:test_tag)

      conn =
        Calcinator.Controller.update(
          conn,
          %{
            "id" => to_string(id),
            "data" => %{
              "type" => "test-posts",
              "id" => to_string(id),
              "attributes" => %{
                "body" => updated_body
              },
              # Test `many_to_many` update does replacement
              "relationships" => %{
                "tags" => %{
                  "data" => [
                    %{
                      "type" => "test-tags",
                      "id" => to_string(updated_test_tag.id)
                    }
                  ]
                }
              }
            },
            "include" => "author,tags",
            "meta" => meta
          },
          %Calcinator{
            associations_by_include: %{
              "author" => :author,
              "tags" => :tags
            },
            ecto_schema_module: TestPost,
            resources_module: TestPosts,
            view_module: TestPostView
          }
        )

      assert %{
               "data" => %{
                 "type" => "test-posts",
                 "attributes" => %{
                   "body" => ^updated_body
                 }
               },
               "included" => included
             } = json_response(conn, :ok)

      assert is_list(included)

      included_by_id_by_type = resource_by_id_by_type(included)

      test_tag_by_id = included_by_id_by_type["test-tags"]

      assert is_map(test_tag_by_id)
      assert map_size(test_tag_by_id) == 1
      assert test_tag_by_id[to_string(updated_test_tag.id)] == test_tag_resource(updated_test_tag)
    end

    test "{:ok, rendered} with sparse fieldset", %{conn: conn} do
      meta = checkout_meta()
      test_tag = Factory.insert(:test_tag)
      %TestPost{author: test_author, id: id} = Factory.insert(:test_post, tags: [test_tag])
      updated_body = "Updated Body"
      updated_test_tag = Factory.insert(:test_tag)

      conn =
        Calcinator.Controller.update(
          conn,
          %{
            "id" => to_string(id),
            "data" => %{
              "type" => "test-posts",
              "id" => to_string(id),
              "attributes" => %{
                "body" => updated_body
              },
              # Test `many_to_many` update does replacement
              "relationships" => %{
                "tags" => %{
                  "data" => [
                    %{
                      "type" => "test-tags",
                      "id" => to_string(updated_test_tag.id)
                    }
                  ]
                }
              }
            },
            "fields" => %{
              # sparse primary
              "test-posts" => "",
              # sparse only 1 of the included tos how sparsing is selective
              "test-authors" => ""
            },
            "include" => "author,tags",
            "meta" => meta
          },
          %Calcinator{
            associations_by_include: %{
              "author" => :author,
              "tags" => :tags
            },
            ecto_schema_module: TestPost,
            resources_module: TestPosts,
            view_module: TestPostView
          }
        )

      assert %{
               "data" => %{
                 "type" => "test-posts",
                 "attributes" => %{}
               },
               "included" => included
             } = json_response(conn, :ok)

      assert is_list(included)

      included_by_id_by_type = resource_by_id_by_type(included)

      test_author_by_id = included_by_id_by_type["test-authors"]

      assert %{"attributes" => test_author_attributes} = test_author_by_id[to_string(test_author.id)]
      assert map_size(test_author_attributes) == 0

      test_tag_by_id = included_by_id_by_type["test-tags"]

      assert is_map(test_tag_by_id)
      assert map_size(test_tag_by_id) == 1
      assert test_tag_by_id[to_string(updated_test_tag.id)] == test_tag_resource(updated_test_tag)
    end

    # has happened when the `carrot_rpc` servers in Ruby crash with a 500 Internal Server error
    test "{:error, :bad_gateway}", %{conn: conn} do
      Application.put_env(:calcinator, TestAuthors, [{:update, {:error, :bad_gateway}}])

      meta = checkout_meta()
      %TestAuthor{id: id} = Factory.insert(:test_author, name: "Alice")

      conn =
        Calcinator.Controller.update(
          conn,
          %{
            "id" => id,
            "data" => %{
              "type" => "test-authors",
              "id" => to_string(id),
              "attributes" => %{
                "name" => "Eve"
              }
            },
            "meta" => meta
          },
          %Calcinator{ecto_schema_module: TestAuthor, resources_module: TestAuthors, view_module: TestAuthorView}
        )

      assert %{"errors" => errors} = json_response(conn, :bad_gateway)
      assert is_list(errors)
      assert length(errors) == 1

      assert %{
               "status" => "502",
               "title" => "Bad Gateway"
             } in errors
    end

    test "{:error, {:not_found, _}}", %{conn: conn} do
      id = -1

      conn =
        Calcinator.Controller.update(
          conn,
          %{
            "id" => id,
            "data" => %{
              "type" => "test-authors",
              "id" => to_string(id),
              "attributes" => %{
                "name" => "Eve"
              }
            },
            "meta" => checkout_meta()
          },
          %Calcinator{ecto_schema_module: TestAuthor, resources_module: TestAuthors, view_module: TestAuthorView}
        )

      assert_not_found(conn, "id")
    end

    test "{:error, :sandbox_access_disallowed}", %{conn: conn} do
      meta = checkout_meta()
      %TestAuthor{id: id} = Factory.insert(:test_author)
      Ecto.Adapters.SQL.Sandbox.checkin(Repo)

      conn =
        Calcinator.Controller.update(
          conn,
          %{
            "id" => id,
            "data" => %{
              "type" => "test-authors",
              "id" => to_string(id),
              "attributes" => %{
                "name" => "Eve"
              }
            },
            "meta" => meta
          },
          %Calcinator{ecto_schema_module: TestAuthor, resources_module: TestAuthors, view_module: TestAuthorView}
        )

      assert_sandox_access_disallowed(conn)
    end

    test "{:error, :sandbox_token_missing}", %{conn: conn} do
      :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
      %TestAuthor{id: id} = Factory.insert(:test_author)

      conn =
        Calcinator.Controller.update(
          conn,
          %{
            "id" => id,
            "data" => %{
              "type" => "test-authors",
              "id" => to_string(id),
              "attributes" => %{
                "name" => "Eve"
              }
            }
          },
          %Calcinator{ecto_schema_module: TestAuthor, resources_module: TestAuthors, view_module: TestAuthorView}
        )

      assert_sandbox_token_missing(conn)
    end

    test "{:error, :timeout} from Calcinator.Resources.get/2", %{conn: conn} do
      Application.put_env(:calcinator, TestAuthors, get: {:error, :timeout})

      meta = checkout_meta()
      %TestAuthor{id: id} = Factory.insert(:test_author)

      conn =
        Calcinator.Controller.update(
          conn,
          %{
            "id" => id,
            "data" => %{
              "type" => "test-authors",
              "id" => to_string(id),
              "attributes" => %{
                "name" => "Eve"
              }
            },
            "meta" => meta
          },
          %Calcinator{ecto_schema_module: TestAuthor, resources_module: TestAuthors, view_module: TestAuthorView}
        )

      assert_timeout(conn)
    end

    test "{:error, :timeout} from Calcinator.Resources.update/1", %{conn: conn} do
      Application.put_env(:calcinator, TestAuthors, update: {:error, :timeout})

      meta = checkout_meta()
      %TestAuthor{id: id} = Factory.insert(:test_author)

      conn =
        Calcinator.Controller.update(
          conn,
          %{
            "id" => id,
            "data" => %{
              "type" => "test-authors",
              "id" => to_string(id),
              "attributes" => %{
                "name" => "Eve"
              }
            },
            "meta" => meta
          },
          %Calcinator{ecto_schema_module: TestAuthor, resources_module: TestAuthors, view_module: TestAuthorView}
        )

      assert_timeout(conn)
    end

    test "{:error, :unauthorized}", %{conn: conn} do
      meta = checkout_meta()
      %TestAuthor{id: id} = Factory.insert(:test_author)

      conn =
        Calcinator.Controller.update(
          conn,
          %{
            "id" => id,
            "data" => %{
              "type" => "test-authors",
              "id" => to_string(id),
              "attributes" => %{
                "name" => "Eve"
              }
            },
            "meta" => meta
          },
          %Calcinator{
            authorization_module: Cant,
            ecto_schema_module: TestAuthor,
            resources_module: TestAuthors,
            view_module: TestAuthorView
          }
        )

      assert_unauthorized(conn)
    end

    test "{:error, Alembic.Document.t}", %{conn: conn} do
      meta = checkout_meta()
      %TestAuthor{id: id} = Factory.insert(:test_author)

      conn =
        Calcinator.Controller.update(
          conn,
          %{
            "id" => id,
            "data" => %{
              "type" => "test-authors",
              "id" => to_string(id),
              "attributes" => %{
                "name" => "Eve"
              }
            },
            "include" => "post",
            "meta" => meta
          },
          %Calcinator{ecto_schema_module: TestAuthor, resources_module: TestAuthors, view_module: TestAuthorView}
        )

      assert %{"errors" => errors} = json_response(conn, 422)
      assert length(errors) == 1

      assert %{
               "detail" => "`post` is an unknown relationship path",
               "meta" => %{
                 "relationship_path" => "post"
               },
               "source" => %{
                 "parameter" => "include"
               },
               "title" => "Unknown relationship path"
             } in errors
    end

    test "{:error, Ecto.Changeset.t}", %{conn: conn} do
      meta = checkout_meta()
      author = %TestAuthor{id: id} = Factory.insert(:test_author)
      Factory.insert(:test_post, author: author)

      conn =
        Calcinator.Controller.update(
          conn,
          %{
            "id" => id,
            "data" => %{
              "type" => "test-authors",
              "id" => to_string(id),
              "attributes" => %{
                "name" => nil
              }
            },
            "meta" => meta
          },
          %Calcinator{ecto_schema_module: TestAuthor, resources_module: TestAuthors, view_module: TestAuthorView}
        )

      assert %{"errors" => errors} = json_response(conn, 422)
      assert length(errors) == 1

      assert %{
               "detail" => "name can't be blank",
               "source" => %{
                 "pointer" => "/data/attributes/name"
               },
               "title" => "can't be blank"
             } in errors
    end

    test "{:error, Ecto.Changeset.t} when many_to_many ID does not exist", %{conn: conn} do
      meta = checkout_meta()
      test_tag = Factory.insert(:test_tag)
      %TestPost{id: id} = Factory.insert(:test_post, tags: [test_tag])
      updated_body = "Updated Body"

      conn =
        Calcinator.Controller.update(
          conn,
          %{
            "id" => to_string(id),
            "data" => %{
              "type" => "test-posts",
              "id" => to_string(id),
              "attributes" => %{
                "body" => updated_body
              },
              # Test `many_to_many` update does replacement
              "relationships" => %{
                "tags" => %{
                  "data" => [
                    %{
                      "type" => "test-tags",
                      "id" => to_string(-1)
                    }
                  ]
                }
              }
            },
            "include" => "author,tags",
            "meta" => meta
          },
          %Calcinator{
            associations_by_include: %{
              "author" => :author,
              "tags" => :tags
            },
            ecto_schema_module: TestPost,
            resources_module: TestPosts,
            view_module: TestPostView
          }
        )

      assert %{"errors" => errors} = json_response(conn, 422)

      assert is_list(errors)
      assert length(errors) == 1

      assert %{
               "detail" => "tags has element at index 0 whose id (-1) does not exist",
               "source" => %{
                 "pointer" => "/data/relationships/tags"
               },
               "title" => "has element at index 0 whose id (-1) does not exist"
             } in errors
    end

    test "{:error, reason}", %{conn: conn} do
      meta = checkout_meta()
      %TestAuthor{id: id} = Factory.insert(:test_author)

      assert_error_reason(:update, fn ->
        Calcinator.Controller.update(
          conn,
          %{
            "id" => id,
            "data" => %{
              "type" => "test-authors",
              "id" => to_string(id),
              "attributes" => %{
                "name" => "Eve"
              }
            },
            "meta" => meta
          },
          %Calcinator{ecto_schema_module: TestAuthor, resources_module: TestAuthors, view_module: TestAuthorView}
        )
      end)
    end
  end

  # Functions

  ## Private Functions

  defp assert_error_reason(action, plug) do
    reason = "A secret reason"
    Application.put_env(:calcinator, TestAuthors, [{action, {:error, reason}}])

    log =
      capture_log([level: :error], fn ->
        conn = plug.()

        assert %{"errors" => errors} = json_response(conn, 500)
        assert [error] = errors

        assert %{
                 "id" => error_id,
                 "status" => "500",
                 "title" => "Internal Server Error"
               } = error

        send(self(), {:error_id, error_id})
      end)

    error_id =
      receive do
        {:error_id, error_id} -> error_id
      end

    assert String.contains?(log, "id=#{error_id} reason=#{inspect(reason)}")
  end

  defp assert_not_found(conn, parameter) do
    assert %{"errors" => errors} = json_response(conn, :not_found)
    assert is_list(errors)
    assert length(errors) == 1

    assert %{
             "source" => %{
               "parameter" => parameter
             },
             "status" => "404",
             "title" => "Resource Not Found"
           } in errors
  end

  defp assert_sandox_access_disallowed(conn) do
    assert %{"errors" => errors} = json_response(conn, 422)
    assert length(errors) == 1

    assert %{
             "detail" => "Information in /meta/beam was not enough to grant access to the sandbox",
             "source" => %{
               "pointer" => "/meta/beam"
             },
             "status" => "422",
             "title" => "Sandbox Access Disallowed"
           } in errors
  end

  defp assert_sandbox_token_missing(conn) do
    assert %{"errors" => errors} = json_response(conn, 422)
    assert length(errors) == 1

    assert %{
             "detail" => "`/meta/beam` is missing",
             "meta" => %{
               "child" => "beam"
             },
             "source" => %{
               "pointer" => "/meta"
             },
             "status" => "422",
             "title" => "Child missing"
           } in errors
  end

  defp assert_timeout(conn) do
    assert %{"errors" => errors} = json_response(conn, 504)
    assert length(errors) == 1

    assert %{
             "status" => "504",
             "title" => "Gateway Timeout"
           } in errors
  end

  defp assert_unauthorized(conn) do
    assert %{"errors" => errors} = json_response(conn, 403)
    assert length(errors) == 1

    assert %{
             "detail" => "You do not have permission for this resource.",
             "status" => "403",
             "title" => "Forbidden"
           } in errors
  end

  def resource_by_id_by_type(included) do
    Enum.reduce(included, %{}, fn resource = %{"id" => id, "type" => type}, resource_by_id_by_type ->
      resource_by_id_by_type
      |> Map.put_new(type, %{})
      |> put_in([type, id], resource)
    end)
  end

  defp test_author_resource(%TestAuthor{id: id, name: name}) do
    %{
      "type" => "test-authors",
      "id" => to_string(id),
      "attributes" => %{
        "name" => name
      },
      "links" => %{
        "self" => "/api/v1/test-authors/#{id}"
      },
      "relationships" => %{
        "posts" => %{}
      }
    }
  end

  defp test_tag_resource(%TestTag{id: id, name: name}) do
    %{
      "type" => "test-tags",
      "id" => to_string(id),
      "attributes" => %{
        "name" => name
      },
      "links" => %{
        "self" => "/api/v1/test-tags/#{id}"
      },
      "relationships" => %{
        "posts" => %{}
      }
    }
  end
end
